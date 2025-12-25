import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'webrtc_adapter.dart';

class MobileWebRtcAdapter implements WebRtcAdapter {
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
    };

    final pc = await rtc.createPeerConnection(configuration);
    return MobilePeerConnection(pc);
  }

  @override
  Future<DataChannel> createDataChannel({
    required PeerConnection peerConnection,
    required String label,
    DataChannelInit? options,
  }) async {
    if (peerConnection is! MobilePeerConnection) {
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
    return MobileDataChannel(dc);
  }

  @override
  Future<MediaStream> getUserMedia(MediaConstraints constraints) async {
    final mConstraints = {
      'audio': constraints.audio,
      'video': constraints.video,
    };
    final stream = await rtc.navigator.mediaDevices.getUserMedia(mConstraints);
    return MobileMediaStream(stream);
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
    return MobileMediaStream(stream);
  }

  @override
  Future<void> dispose() async {}
}

class MobilePeerConnection implements PeerConnection {
  final rtc.RTCPeerConnection rtcConnection;
  final _connectionStateController =
      StreamController<PeerConnectionState>.broadcast();
  final _iceCandidateController = StreamController<IceCandidate>.broadcast();
  final _dataChannelController = StreamController<DataChannel>.broadcast();
  final _trackController = StreamController<MediaStream>.broadcast();

  MobilePeerConnection(this.rtcConnection) {
    rtcConnection.onConnectionState = (state) {
      _connectionStateController.add(_mapConnectionState(state));
    };

    rtcConnection.onIceCandidate = (candidate) {
      _iceCandidateController.add(
        IceCandidate(
          candidate: candidate.candidate ?? '',
          sdpMid: candidate.sdpMid,
          sdpMLineIndex: candidate.sdpMLineIndex,
        ),
      );
    };

    rtcConnection.onDataChannel = (dc) {
      _dataChannelController.add(MobileDataChannel(dc));
    };

    rtcConnection.onTrack = (track) {
      // NOTE: Mobile handles tracks differently, often wrapping them in streams
      // For simplicity in this adapter, we might need to adjust based on how tracks are received.
      if (track.streams.isNotEmpty) {
        _trackController.add(MobileMediaStream(track.streams[0]));
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
  Stream<PeerConnectionState> get onConnectionState =>
      _connectionStateController.stream;

  @override
  Stream<IceCandidate> get onIceCandidate => _iceCandidateController.stream;

  @override
  Stream<DataChannel> get onDataChannel => _dataChannelController.stream;

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

class MobileDataChannel implements DataChannel {
  final rtc.RTCDataChannel _dc;
  final _messageController = StreamController<dynamic>.broadcast();
  final _stateController = StreamController<DataChannelState>.broadcast();

  MobileDataChannel(this._dc) {
    _dc.onMessage = (message) {
      _messageController.add(message.text);
    };
    _dc.onDataChannelState = (state) {
      _stateController.add(_mapState(state));
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

class MobileMediaStream implements MediaStream {
  final rtc.MediaStream _stream;

  MobileMediaStream(this._stream);

  @override
  String get id => _stream.id;

  @override
  List<MediaTrack> getTracks() {
    return _stream.getTracks().map((t) => MobileMediaTrack(t)).toList();
  }

  @override
  Future<void> dispose() async {
    await _stream.dispose();
  }
}

class MobileMediaTrack implements MediaTrack {
  final rtc.MediaStreamTrack _track;

  MobileMediaTrack(this._track);

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
