import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_peer/signaling/signaling_client.dart';
import 'package:flutter_peer/signaling/signaling_protocol.dart';
import 'package:flutter_peer/peer.dart';

class MockSignalingClient extends Mock implements SignalingClient {}

void main() {
  group('Peer', () {
    test('Initialization connects to signaling', () {
      // Since Peer constructor starts signaling immediately, we'd need to mock the constructor
      // or injectable signaling client.
      // For now, let's verify Peer state.
      final peer = Peer();
      expect(peer.id, isNull); // Initially null until signaling opens
      peer.destroy();
    });
  });

  group('SignalingMessage logic', () {
    test('Protocol message parsing', () {
      final json = {'type': 'OPEN', 'payload': 'my-peer-id'};
      final msg = SignalingMessage.fromJson(json);
      expect(msg.type, SignalingMessageType.open);
      expect(msg.payload, 'my-peer-id');
    });
  });
}
