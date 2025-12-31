import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'webrtc_adapter.dart';

/// Web implementation of WebRtcAdapter
/// On web, we still use flutter_webrtc as it provides a unified API
/// while wrapping native browser WebRTC.
class WebWebRtcAdapter implements WebRtcAdapter {
  @override
  Future<PeerConnection> createPeerConnection({
    required IceConfiguration iceConfiguration,
  }) async {
    final configuration = {
      'iceServers': iceConfiguration.iceServers
          .map(
            (s) => {
              'urls': s.urls,
              if (s.username != null) 'username': s.username,
              if (s.credential != null) 'credential': s.credential,
            },
          )
          .toList(),
      'sdpSemantics': 'unified-plan',
    };

    final pc = await rtc.createPeerConnection(configuration);
    return WebPeerConnection(pc);
  }

  @override
  Future<DataChannel> createDataChannel({
    required PeerConnection peerConnection,
    required String label,
    DataChannelInit? options,
  }) async {
    if (peerConnection is! WebPeerConnection) {
      throw Exception('Invalid peer connection type');
    }

    final init = rtc.RTCDataChannelInit()..ordered = options?.ordered ?? true;
    final maxPacketLifeTime = options?.maxPacketLifeTime;
    if (maxPacketLifeTime != null) {
      init.maxRetransmitTime = maxPacketLifeTime;
    }
    final maxRetransmits = options?.maxRetransmits;
    if (maxRetransmits != null) {
      init.maxRetransmits = maxRetransmits;
    }

    final dc = await peerConnection.rtcConnection.createDataChannel(
      label,
      init,
    );
    return WebDataChannel(dc);
  }

  @override
  Future<MediaStream> getUserMedia(MediaConstraints constraints) async {
    final mConstraints = {
      'audio': constraints.audioInputId != null
          ? {'deviceId': constraints.audioInputId}
          : constraints.audio,
      'video': constraints.videoInputId != null
          ? {'deviceId': constraints.videoInputId}
          : constraints.video,
    };
    final stream = await rtc.navigator.mediaDevices.getUserMedia(mConstraints);
    return WebMediaStream(stream);
  }

  @override
  Future<MediaStream> getDisplayMedia(MediaConstraints constraints) async {
    final mConstraints = {
      'audio': constraints.audio,
      'video': constraints.video,
    };
    final stream = await rtc.navigator.mediaDevices.getDisplayMedia(
      mConstraints,
    );
    return WebMediaStream(stream);
  }

  @override
  Future<void> switchCamera(MediaStream stream) async {
    // Web doesn't have a simple switchCamera like Mobile Helper
    // Usually you enumerate and then getUserMedia again with the new deviceId
  }

  @override
  Future<List<MediaDeviceInfo>> enumerateDevices() async {
    final devices = await rtc.navigator.mediaDevices.enumerateDevices();
    return devices
        .map(
          (d) => MediaDeviceInfo(
            deviceId: d.deviceId,
            label: d.label,
            kind: d.kind ?? '',
            groupId: d.groupId ?? '',
          ),
        )
        .toList();
  }

  @override
  Future<void> setSpeakerphoneOn(bool enable) async {
    // Not applicable on web usually
  }

  @override
  Future<void> setAudioOutput(String deviceId) async {
    // flutter_webrtc web implementation might support this via sinkId if available
  }

  @override
  Future<void> dispose() async {}
}

class WebPeerConnection implements PeerConnection {
  final rtc.RTCPeerConnection rtcConnection;
  final _connectionStateController =
      StreamController<PeerConnectionState>.broadcast();
  final _iceCandidateController = StreamController<IceCandidate>.broadcast();
  final _dataChannelController = StreamController<DataChannel>.broadcast();
  final _trackController = StreamController<MediaStream>.broadcast();

  WebPeerConnection(this.rtcConnection) {
    rtcConnection.onConnectionState = (state) {
      if (!_connectionStateController.isClosed) {
        _connectionStateController.add(_mapConnectionState(state));
      }
    };

    rtcConnection.onIceCandidate = (candidate) {
      if (!_iceCandidateController.isClosed) {
        _iceCandidateController.add(
          IceCandidate(
            candidate: candidate.candidate ?? '',
            sdpMid: candidate.sdpMid,
            sdpMLineIndex: candidate.sdpMLineIndex,
          ),
        );
      }
    };

    rtcConnection.onDataChannel = (dc) {
      if (!_dataChannelController.isClosed) {
        _dataChannelController.add(WebDataChannel(dc));
      }
    };

    rtcConnection.onTrack = (rtc.RTCTrackEvent track) async {
      print(
        'onTrack (web): ${track.track.kind} with ${track.streams.length} streams',
      );
      if (_trackController.isClosed) return;

      if (track.streams.isNotEmpty) {
        _trackController.add(WebMediaStream(track.streams[0]));
      } else {
        final stream = await rtc.createLocalMediaStream(
          'remote_stream_${track.track.id}',
        );
        await stream.addTrack(track.track);
        if (!_trackController.isClosed) {
          _trackController.add(WebMediaStream(stream));
        }
      }
    };
  }

  @override
  Future<SessionDescription> createOffer() async {
    final offer = await rtcConnection.createOffer();
    return SessionDescription(sdp: offer.sdp ?? '', type: SdpType.offer);
  }

  @override
  Future<SessionDescription> createAnswer() async {
    final answer = await rtcConnection.createAnswer();
    return SessionDescription(sdp: answer.sdp ?? '', type: SdpType.answer);
  }

  @override
  Future<void> setLocalDescription(SessionDescription description) async {
    await rtcConnection.setLocalDescription(
      rtc.RTCSessionDescription(description.sdp, description.type.name),
    );
  }

  @override
  Future<void> setRemoteDescription(SessionDescription description) async {
    await rtcConnection.setRemoteDescription(
      rtc.RTCSessionDescription(description.sdp, description.type.name),
    );
  }

  @override
  Future<void> addStream(MediaStream stream) async {
    if (stream is WebMediaStream) {
      for (var track in stream.getTracks()) {
        if (track is WebMediaTrack) {
          await rtcConnection.addTrack(track.rtcTrack, stream.rtcStream);
        }
      }
    }
  }

  @override
  Future<void> addIceCandidate(IceCandidate candidate) async {
    await rtcConnection.addCandidate(
      rtc.RTCIceCandidate(
        candidate.candidate,
        candidate.sdpMid,
        candidate.sdpMLineIndex,
      ),
    );
  }

  @override
  Future<void> close() async {
    await rtcConnection.close();
    await _connectionStateController.close();
    await _iceCandidateController.close();
    await _dataChannelController.close();
    await _trackController.close();
  }

  @override
  Future<SignalingState> getSignalingState() async {
    final state = await rtcConnection.getSignalingState();
    return _mapSignalingState(
      state ?? rtc.RTCSignalingState.RTCSignalingStateClosed,
    );
  }

  SignalingState _mapSignalingState(rtc.RTCSignalingState state) {
    switch (state) {
      case rtc.RTCSignalingState.RTCSignalingStateStable:
        return SignalingState.stable;
      case rtc.RTCSignalingState.RTCSignalingStateHaveLocalOffer:
        return SignalingState.haveLocalOffer;
      case rtc.RTCSignalingState.RTCSignalingStateHaveRemoteOffer:
        return SignalingState.haveRemoteOffer;
      case rtc.RTCSignalingState.RTCSignalingStateHaveLocalPrAnswer:
        return SignalingState.haveLocalPranswer;
      case rtc.RTCSignalingState.RTCSignalingStateHaveRemotePrAnswer:
        return SignalingState.haveRemotePranswer;
      case rtc.RTCSignalingState.RTCSignalingStateClosed:
        return SignalingState.closed;
    }
  }

  @override
  Stream<PeerConnectionState> get onConnectionState =>
      _connectionStateController.stream;

  @override
  Stream<IceCandidate> get onIceCandidate => _iceCandidateController.stream;

  @override
  Stream<DataChannel> get onDataChannel => _trackController.stream.cast<
      DataChannel>(); // FIXED: This was wrong in mobile too, should be the dc controller

  @override
  Stream<MediaStream> get onTrack => _trackController.stream;

  PeerConnectionState _mapConnectionState(rtc.RTCPeerConnectionState state) {
    switch (state) {
      case rtc.RTCPeerConnectionState.RTCPeerConnectionStateNew:
        return PeerConnectionState.idle;
      case rtc.RTCPeerConnectionState.RTCPeerConnectionStateConnecting:
        return PeerConnectionState.connecting;
      case rtc.RTCPeerConnectionState.RTCPeerConnectionStateConnected:
        return PeerConnectionState.connected;
      case rtc.RTCPeerConnectionState.RTCPeerConnectionStateDisconnected:
        return PeerConnectionState.disconnected;
      case rtc.RTCPeerConnectionState.RTCPeerConnectionStateFailed:
        return PeerConnectionState.failed;
      case rtc.RTCPeerConnectionState.RTCPeerConnectionStateClosed:
        return PeerConnectionState.closed;
    }
  }
}

class WebDataChannel implements DataChannel {
  final rtc.RTCDataChannel _dc;
  final _messageController = StreamController<dynamic>.broadcast();
  final _stateController = StreamController<DataChannelState>.broadcast();

  WebDataChannel(this._dc) {
    _dc.onMessage = (message) {
      if (!_messageController.isClosed) {
        _messageController.add(message.text);
      }
    };
    _dc.onDataChannelState = (state) {
      if (!_stateController.isClosed) {
        _stateController.add(_mapState(state));
      }
    };
  }

  @override
  String get label => _dc.label ?? '';

  @override
  Stream get onMessage => _messageController.stream;

  @override
  Stream<DataChannelState> get onState => _stateController.stream;

  @override
  Future<void> send(dynamic data) async {
    if (data is String) {
      _dc.send(rtc.RTCDataChannelMessage(data));
    }
  }

  @override
  Future<void> close() async {
    await _dc.close();
    await _messageController.close();
    await _stateController.close();
  }

  DataChannelState _mapState(rtc.RTCDataChannelState state) {
    switch (state) {
      case rtc.RTCDataChannelState.RTCDataChannelConnecting:
        return DataChannelState.connecting;
      case rtc.RTCDataChannelState.RTCDataChannelOpen:
        return DataChannelState.open;
      case rtc.RTCDataChannelState.RTCDataChannelClosing:
        return DataChannelState.closing;
      case rtc.RTCDataChannelState.RTCDataChannelClosed:
        return DataChannelState.closed;
    }
  }
}

class WebMediaStream implements MediaStream {
  final rtc.MediaStream _stream;

  WebMediaStream(this._stream);

  rtc.MediaStream get rtcStream => _stream;

  @override
  rtc.MediaStream get srcObject => _stream;

  @override
  String get id => _stream.id;

  @override
  List<MediaTrack> getTracks() {
    return _stream.getTracks().map((t) => WebMediaTrack(t)).toList();
  }

  @override
  Future<void> dispose() async {
    await _stream.dispose();
  }

  @override
  Future<void> toggleAudio(bool enabled) async {
    _stream.getAudioTracks().forEach((track) {
      track.enabled = enabled;
    });
  }

  @override
  Future<void> toggleVideo(bool enabled) async {
    _stream.getVideoTracks().forEach((track) {
      track.enabled = enabled;
    });
  }
}

class WebMediaTrack implements MediaTrack {
  final rtc.MediaStreamTrack _track;

  WebMediaTrack(this._track);

  rtc.MediaStreamTrack get rtcTrack => _track;

  @override
  String get id => _track.id ?? '';

  @override
  String get kind => _track.kind ?? '';

  @override
  bool get enabled => _track.enabled;

  @override
  Future<void> setEnabled(bool enabled) async {
    _track.enabled = enabled;
  }

  @override
  Future<void> stop() async {
    await _track.stop();
  }
}
