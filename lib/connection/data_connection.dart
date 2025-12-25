import 'dart:async';
import 'base_connection.dart';
import '../webrtc/webrtc_adapter.dart';
import '../signaling/signaling_protocol.dart';

class DataConnection extends BaseConnection {
  final String label;
  final DataChannelInit? options;
  DataChannel? _dc;

  DataConnection({
    required super.peerId,
    required super.signalingClient,
    required super.adapter,
    required super.connectionId,
    this.label = 'peerjs',
    this.options,
  });

  @override
  Future<void> initialize() async {
    pc = await adapter.createPeerConnection(
      iceConfiguration: const IceConfiguration(
        iceServers: [
          IceServer(urls: ['stun:stun.l.google.com:19302']),
        ],
      ),
    );

    pc!.onIceCandidate.listen((candidate) {
      sendSignal(SignalingMessageType.candidate, {
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    });

    pc!.onConnectionState.listen((state) {
      if (state == PeerConnectionState.connected) {
        emit('open');
      } else if (state == PeerConnectionState.closed ||
          state == PeerConnectionState.failed) {
        close();
      }
    });

    pc!.onDataChannel.listen(_handleDataChannel);
  }

  Future<void> connect() async {
    await initialize();
    _dc = await adapter.createDataChannel(
      peerConnection: pc!,
      label: label,
      options: options,
    );
    _setupDataChannel(_dc!);

    final offer = await pc!.createOffer();
    await pc!.setLocalDescription(offer);
    sendSignal(SignalingMessageType.offer, {
      'sdp': offer.sdp,
      'type': offer.type.name,
    });
  }

  void _handleDataChannel(DataChannel dc) {
    _dc = dc;
    _setupDataChannel(dc);
  }

  void _setupDataChannel(DataChannel dc) {
    dc.onState.listen((state) {
      if (state == DataChannelState.open) {
        isOpen = true;
        emit('open');
      } else if (state == DataChannelState.closed) {
        isOpen = false;
        emit('close');
      }
    });

    dc.onMessage.listen((data) {
      emit('data', this, data);
    });
  }

  @override
  void handleMessage(SignalingMessage message) async {
    final payload = message.payload['payload'];

    switch (message.type) {
      case SignalingMessageType.offer:
        if (pc == null) await initialize();
        await pc!.setRemoteDescription(
          SessionDescription(sdp: payload['sdp'], type: SdpType.offer),
        );
        final answer = await pc!.createAnswer();
        await pc!.setLocalDescription(answer);
        sendSignal(SignalingMessageType.answer, {
          'sdp': answer.sdp,
          'type': answer.type.name,
        });
        break;
      case SignalingMessageType.answer:
        await pc!.setRemoteDescription(
          SessionDescription(sdp: payload['sdp'], type: SdpType.answer),
        );
        break;
      case SignalingMessageType.candidate:
        await pc!.addIceCandidate(
          IceCandidate(
            candidate: payload['candidate'],
            sdpMid: payload['sdpMid'],
            sdpMLineIndex: payload['sdpMLineIndex'],
          ),
        );
        break;
      default:
        break;
    }
  }

  void send(dynamic data) {
    if (_dc != null && isOpen) {
      _dc!.send(data);
    }
  }

  @override
  void close() {
    _dc?.close();
    pc?.close();
    isOpen = false;
    emit('close');
  }
}
