import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:eventify/eventify.dart';
import 'signaling_protocol.dart';

class SignalingClient extends EventEmitter {
  final String host;
  final int port;
  final String path;
  final bool secure;
  final String key;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _id;
  bool _connected = false;

  SignalingClient({
    required this.host,
    required this.port,
    this.path = '/',
    this.secure = true,
    this.key = 'peerjs',
  });

  String? get id => _id;
  bool get isConnected => _connected;

  Future<void> connect([String? id]) async {
    final protocol = secure ? 'wss' : 'ws';
    final randomToken = _generateToken();

    // PeerJS signaling URL format: ws://host:port/path/peerjs?key=...&id=...&token=...
    final url = Uri.parse(
      '$protocol://$host:$port$path'
      'peerjs?key=$key&id=${id ?? ""}&token=$randomToken',
    );

    _channel = WebSocketChannel.connect(url);
    _connected = true;

    _subscription = _channel!.stream.listen(
      (data) {
        final Map<String, dynamic> json = jsonDecode(data);
        final message = SignalingMessage.fromJson(json);
        _handleMessage(message);
      },
      onDone: () => _handleDisconnect(),
      onError: (err) => _handleError(err),
    );
  }

  void send(SignalingMessage message) {
    if (_channel != null && _connected) {
      _channel!.sink.add(jsonEncode(message.toJson()));
    }
  }

  void _handleMessage(SignalingMessage message) {
    switch (message.type) {
      case SignalingMessageType.open:
        _id = message.payload;
        emit('open', this, _id);
        break;
      case SignalingMessageType.error:
        emit('error', this, message.payload);
        break;
      case SignalingMessageType.idTaken:
        emit('error', this, 'ID is already taken');
        break;
      case SignalingMessageType.invalidId:
        emit('error', this, 'Invalid ID');
        break;
      case SignalingMessageType.offer:
      case SignalingMessageType.answer:
      case SignalingMessageType.candidate:
      case SignalingMessageType.leave:
      case SignalingMessageType.expire:
        emit('message', this, message);
        break;
    }
  }

  void _handleDisconnect() {
    _connected = false;
    emit('disconnected', this);
  }

  void _handleError(dynamic err) {
    emit('error', this, err);
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _connected = false;
  }

  String _generateToken() {
    return (DateTime.now().millisecondsSinceEpoch % 1000000).toString();
  }
}
