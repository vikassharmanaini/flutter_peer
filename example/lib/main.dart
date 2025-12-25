import 'package:flutter/material.dart';
import 'package:flutter_peer/flutter_peer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Peer peer;
  String? myId;
  String destId = '';
  final TextEditingController _msgController = TextEditingController();
  final List<String> messages = [];
  DataConnection? activeConn;

  @override
  void initState() {
    super.initState();
    _initPeer();
  }

  void _initPeer() {
    peer = Peer();

    peer.on('open', null, (ev, id) {
      setState(() {
        myId = id as String?;
      });
    });

    peer.on('connection', null, (ev, conn) {
      _setupConnection(conn as DataConnection);
    });

    peer.on('error', null, (ev, err) {
      debugPrint('Peer error: $err');
    });
  }

  void _setupConnection(DataConnection conn) {
    setState(() {
      activeConn = conn;
    });

    conn.on('open', null, (ev, _) {
      setState(() {
        messages.add('Connected to ${conn.peerId}');
      });
    });

    conn.on('data', null, (ev, data) {
      setState(() {
        messages.add('${conn.peerId}: $data');
      });
    });

    conn.on('close', null, (ev, _) {
      setState(() {
        messages.add('Disconnected');
        activeConn = null;
      });
    });
  }

  void _connect() {
    if (destId.isNotEmpty) {
      final conn = peer.connect(destId);
      _setupConnection(conn);
    }
  }

  void _send() {
    if (activeConn != null && _msgController.text.isNotEmpty) {
      activeConn!.send(_msgController.text);
      setState(() {
        messages.add('Me: ${_msgController.text}');
        _msgController.clear();
      });
    }
  }

  @override
  void dispose() {
    peer.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter Peer Example')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                'My ID: ${myId ?? "Connecting..."}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Destination Peer ID',
                      ),
                      onChanged: (v) => destId = v,
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _connect,
                    child: const Text('Connect'),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: messages.length,
                  itemBuilder: (context, i) => Text(messages[i]),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                      ),
                    ),
                  ),
                  IconButton(onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
