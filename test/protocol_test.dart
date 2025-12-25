import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_peer/signaling/signaling_protocol.dart';

void main() {
  group('SignalingMessage', () {
    test('toJson/fromJson roundtrip', () {
      final msg = SignalingMessage(
        type: SignalingMessageType.offer,
        src: 'src-id',
        dst: 'dst-id',
        payload: {'sdp': 'v=0...'},
      );

      final json = msg.toJson();
      expect(json['type'], 'OFFER');
      expect(json['src'], 'src-id');
      expect(json['dst'], 'dst-id');
      expect(json['payload'], {'sdp': 'v=0...'});

      final fromJson = SignalingMessage.fromJson(json);
      expect(fromJson.type, SignalingMessageType.offer);
      expect(fromJson.src, 'src-id');
      expect(fromJson.dst, 'dst-id');
      expect(fromJson.payload, {'sdp': 'v=0...'});
    });

    test('error type fallback on invalid json', () {
      final json = {'type': 'INVALID_TYPE'};
      final fromJson = SignalingMessage.fromJson(json);
      expect(fromJson.type, SignalingMessageType.error);
    });
  });
}
