import 'package:eventify/eventify.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';

import 'signaling/signaling_client.dart';
import 'signaling/signaling_protocol.dart';
import 'webrtc/webrtc_adapter.dart';
import 'webrtc/webrtc_mobile.dart';
import 'webrtc/webrtc_web.dart';
import 'connection/data_connection.dart';
import 'connection/base_connection.dart';

class Peer extends EventEmitter {
  final SignalingClient _signaling;
  final WebRtcAdapter _adapter;
  final Map<String, BaseConnection> _connections = {};

  static const _uuid = Uuid();

  Peer({
    String? id,
    String host = '0.peerjs.com',
    int port = 443,
    String path = '/',
    bool secure = true,
    String key = 'peerjs',
  }) : _adapter = kIsWeb ? WebWebRtcAdapter() : MobileWebRtcAdapter(),
       _signaling = SignalingClient(
         host: host,
         port: port,
         path: path,
         secure: secure,
         key: key,
       ) {
    _setupSignaling(id);
  }

  String? get id => _signaling.id;

  void _setupSignaling(String? id) {
    _signaling.on('open', null, (ev, context) {
      emit('open', null, _signaling.id);
    });

    _signaling.on('error', null, (ev, error) {
      emit('error', null, error);
    });

    _signaling.on('message', null, (ev, msg) {
      if (msg is SignalingMessage) {
        _handleIncomingMessage(msg);
      }
    });

    _signaling.connect(id);
  }

  void _handleIncomingMessage(SignalingMessage message) {
    final connectionId = message.payload['connectionId'];
    if (connectionId == null) return;

    var connection = _connections[connectionId];

    if (connection == null) {
      if (message.type == SignalingMessageType.offer) {
        // Incoming connection request
        final src = message.src!;
        // Determine if it's data or media based on payload or implementation detail
        // For simplicity, let's assume DataConnection for now or add metadata to signaling
        connection = DataConnection(
          peerId: src,
          signalingClient: _signaling,
          adapter: _adapter,
          connectionId: connectionId,
        );
        _connections[connectionId] = connection;
        emit('connection', this, connection);
      } else {
        return; // Orphaned message
      }
    }

    connection.handleMessage(message);
  }

  DataConnection connect(
    String peerId, {
    String? label,
    DataChannelInit? options,
  }) {
    final connectionId = _uuid.v4();
    final connection = DataConnection(
      peerId: peerId,
      signalingClient: _signaling,
      adapter: _adapter,
      connectionId: connectionId,
      label: label ?? 'peerjs',
      options: options,
    );

    _connections[connectionId] = connection;
    connection.connect(); // Start negotiation
    return connection;
  }

  // MediaConnection call(String peerId, MediaStream stream) { ... }

  void disconnect() {
    _signaling.disconnect();
    for (var conn in _connections.values) {
      conn.close();
    }
    _connections.clear();
  }

  void destroy() {
    disconnect();
    _adapter.dispose();
  }
}
