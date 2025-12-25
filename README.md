# Flutter Peer

A developer-friendly, lightweight, and reliable WebRTC plugin for Flutter, inspired by [PeerJS](https://peerjs.com/). Establish direct peer-to-peer data, video, and audio connections with ease.

## 🚀 Features

- **Cross-Platform**: Works out-of-the-box on Android, iOS, Web, and Desktop.
- **PeerJS Protocol**: Fully compatible with existing `peerjs-server` instances.
- **Simplicity**: No complex WebRTC negotiation (SDP/ICE) to manage; just use IDs to connect.
- **Standard-compliant**: Uses standard WebRTC under the hood via `flutter_webrtc`.

## 📦 Installation

Add `flutter_peer` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_peer: ^0.0.1
```

## 🛠️ Quick Start

### 1. Initialize Peer

```dart
import 'package:flutter_peer/flutter_peer.dart';

// Automatically connects to the default PeerJS server (0.peerjs.com)
final peer = Peer();

peer.on('open', null, (ev, id) {
  print('My peer ID is: $id');
});
```

### 2. Connect to a Peer

```dart
final conn = peer.connect('another-peer-id');

conn.on('open', null, (ev, _) {
  conn.send('Hello from Flutter!');
});
```

### 3. Receive a Connection

```dart
peer.on('connection', null, (ev, conn) {
  final dataConn = conn as DataConnection;
  
  dataConn.on('data', null, (ev, data) {
    print('Received: $data');
  });
});
```

## ⚙️ Configuration

You can configure the signaling server, port, and key:

```dart
final peer = Peer(
  id: 'my-custom-id',
  host: 'your-peer-server.com',
  port: 443,
  secure: true,
  key: 'peerjs',
);
```

## 📱 Platform Support

| Platform | Support |
| :--- | :--- |
| **Android** | ✅ |
| **iOS** | ✅ |
| **Web** | ✅ |
| **MacOS/Windows/Linux** | ✅ |

## 📄 License

This project is licensed under the Apache 2.0 License.
