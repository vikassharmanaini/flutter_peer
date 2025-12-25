import 'dart:async';
import 'package:eventify/eventify.dart';
import '../webrtc/webrtc_adapter.dart';
import '../signaling/signaling_client.dart';
import '../signaling/signaling_protocol.dart';

abstract class BaseConnection extends EventEmitter {
  final String peerId;
  final SignalingClient signalingClient;
  final WebRtcAdapter adapter;
  final String connectionId;

  PeerConnection? pc;
  bool isOpen = false;

  BaseConnection({
    required this.peerId,
    required this.signalingClient,
    required this.adapter,
    required this.connectionId,
  });

  bool get isConnected => isOpen;

  Future<void> initialize();
  void handleMessage(SignalingMessage message);
  void close();

  void sendSignal(SignalingMessageType type, dynamic payload) {
    signalingClient.send(
      SignalingMessage(
        type: type,
        src: signalingClient.id,
        dst: peerId,
        payload: {'connectionId': connectionId, 'payload': payload},
      ),
    );
  }
}
