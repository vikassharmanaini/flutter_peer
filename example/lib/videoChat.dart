import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_peer/flutter_peer.dart';
import 'package:uuid/uuid.dart';

class Videochat extends StatefulWidget {
  const Videochat({super.key});

  @override
  State<Videochat> createState() => _VideochatState();
}

class _VideochatState extends State<Videochat> {
  late Peer peer;
  String? myId;
  String destId = '';
  MediaConnection? activeCall;
  MediaStream? localStream;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initPeer();
  }

  Future<void> _initPeer() async {
    final id = Uuid().v4();
    peer = Peer(id: id);

    peer.onOpen((id) {
      if (mounted) setState(() => myId = id);
    });

    peer.onCall((call) async {
      // Prompt user or answer automatically
      // For this example, we answer automatically but ensure we have a stream
      await _handleIncomingCall(call);
    });

    try {
      localStream = await peer.getLocalStream();
    } catch (e) {
      debugPrint('Error getting local stream: $e');
      if (mounted) {
        // Clipboard.setData(ClipboardData(text: 'Failed to get camera/mic: $e'));
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to get camera/mic: $e')));
      }
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  void _setupCall(MediaConnection call) {
    setState(() => activeCall = call);

    call.onStream((stream) {
      if (mounted) setState(() {});
    });

    call.onRemoteStreamChange((change) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Remote audio: ${change.audio ? "ON" : "OFF"}, '
            'Remote video: ${change.video ? "ON" : "OFF"}',
          ),
          duration: const Duration(seconds: 1),
        ),
      );
      setState(() {});
    });

    call.onClose(() {
      if (mounted) setState(() => activeCall = null);
    });
  }

  Future<void> _handleIncomingCall(MediaConnection call) async {
    if (localStream == null) {
      // Try to get stream again if missing
      try {
        localStream = await peer.getLocalStream();
      } catch (e) {
        debugPrint('Cannot answer call without stream: $e');
        return;
      }
    }

    await call.answer(localStream!);
    _setupCall(call);
  }

  void _makeCall() async {
    if (destId.isEmpty) return;
    if (localStream == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No local stream available')),
      );
      return;
    }

    final call = peer.call(destId, localStream!);
    _setupCall(call);
  }

  @override
  void dispose() {
    peer.destroy();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Simplified Video Chat')),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      SelectableText(
                        'My ID: ${myId ?? "Connecting..."}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextField(
                        decoration: const InputDecoration(
                          hintText: 'Remote ID',
                        ),
                        onChanged: (v) => destId = v,
                      ),
                      ElevatedButton(
                        onPressed: _makeCall,
                        child: const Text('Call'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      // Remote Video
                      if (activeCall?.remoteStream != null)
                        PeerVideoView(
                          stream: activeCall!.remoteStream!,
                          objectFit: PeerVideoViewObjectFit.cover,
                        )
                      else
                        const Center(child: Text('Waiting for video...')),

                      // Local Video
                      if (localStream != null)
                        Positioned(
                          right: 20,
                          bottom: 20,
                          width: 120,
                          height: 160,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white),
                              color: Colors.black54,
                            ),
                            child: PeerVideoView(
                              stream: localStream,
                              mirror: true,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (activeCall != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      alignment: WrapAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.switch_camera, size: 30),
                          onPressed: () => activeCall?.switchCamera(),
                          tooltip: 'Switch Camera',
                        ),
                        IconButton(
                          icon: const Icon(Icons.videocam_off, size: 30),
                          onPressed: () => activeCall?.turnOffCamera(),
                          tooltip: 'Toggle Camera',
                        ),
                        IconButton(
                          icon: const Icon(Icons.volume_up, size: 30),
                          onPressed: () => activeCall?.switchSpeakers(),
                          tooltip: 'Switch Speakers',
                        ),
                        IconButton(
                          icon: const Icon(Icons.mic_off, size: 30),
                          onPressed: () => activeCall?.turnoffMicrophone(),
                          tooltip: 'Toggle Mic',
                        ),
                        IconButton(
                          icon: const Icon(Icons.mic_external_on, size: 30),
                          onPressed: () => activeCall?.switchMicrophone(),
                          tooltip: 'Switch Mic',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.call_end,
                            color: Colors.red,
                            size: 40,
                          ),
                          onPressed: () => activeCall?.close(),
                          tooltip: 'Hang up',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
