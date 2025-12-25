import 'dart:async';
import 'base_connection.dart';
import '../webrtc/webrtc_adapter.dart';
import '../signaling/signaling_protocol.dart';

class MediaConnection extends BaseConnection {
  final MediaStream? localStream;
  MediaStream? remoteStream;

  MediaConnection({
    required super.peerId,
    required super.signalingClient,
    required super.adapter,
    required super.connectionId,
    this.localStream,
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

    pc!.onTrack.listen((stream) {
      remoteStream = stream;
      isOpen = true;
      emit('stream', this, stream);
    });

    // Add local stream if present
    if (localStream != null) {
      // NOTE: Adapter should support adding tracks/streams to PC
      // For now, we assume provide this via PC directly or wrapper
      // Base logic:
      // pc.addStream(localStream);
    }
  }

  Future<void> answer(MediaStream stream) async {
    // Implement answer logic with local stream
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
        // User must call .answer() to send back their stream/SDP
        emit('call', this);
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

  @override
  void close() {
    pc?.close();
    remoteStream?.dispose();
    isOpen = false;
    emit('close');
  }
}
