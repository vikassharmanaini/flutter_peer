/// WebRTC adapter interface
///
/// This file defines a platform-agnostic contract that every
/// WebRTC implementation (web, mobile, desktop) must follow.
///
/// ❌ No flutter_webrtc imports
/// ❌ No dart:html imports
/// ✅ Pure Dart
///
/// Inspired by PeerJS architecture.

library webrtc_adapter;

/// Represents a generic WebRTC peer connection
abstract class PeerConnection {
  /// Create an SDP offer
  Future<SessionDescription> createOffer();

  /// Create an SDP answer
  Future<SessionDescription> createAnswer();

  /// Set local SDP
  Future<void> setLocalDescription(SessionDescription description);

  /// Set remote SDP
  Future<void> setRemoteDescription(SessionDescription description);

  /// Add ICE candidate
  Future<void> addIceCandidate(IceCandidate candidate);

  /// Close connection
  Future<void> close();

  /// Connection state stream
  Stream<PeerConnectionState> get onConnectionState;

  /// ICE candidate stream
  Stream<IceCandidate> get onIceCandidate;

  /// Data channel stream (incoming)
  Stream<DataChannel> get onDataChannel;

  /// Remote media stream stream
  Stream<MediaStream> get onTrack;
}

/// WebRTC adapter contract
abstract class WebRtcAdapter {
  /// Create a peer connection
  Future<PeerConnection> createPeerConnection({
    required IceConfiguration iceConfiguration,
  });

  /// Create a data channel
  Future<DataChannel> createDataChannel({
    required PeerConnection peerConnection,
    required String label,
    DataChannelInit? options,
  });

  /// Get user media (camera/microphone)
  Future<MediaStream> getUserMedia(MediaConstraints constraints);

  /// Get display media (screen sharing)
  Future<MediaStream> getDisplayMedia(MediaConstraints constraints);

  /// Dispose adapter
  Future<void> dispose();
}

/// ICE configuration
class IceConfiguration {
  final List<IceServer> iceServers;

  const IceConfiguration({required this.iceServers});
}

/// ICE server
class IceServer {
  final List<String> urls;
  final String? username;
  final String? credential;

  const IceServer({
    required this.urls,
    this.username,
    this.credential,
  });
}

/// SDP description
class SessionDescription {
  final String sdp;
  final SdpType type;

  const SessionDescription({
    required this.sdp,
    required this.type,
  });
}

/// SDP type
enum SdpType {
  offer,
  answer,
}

/// ICE candidate
class IceCandidate {
  final String candidate;
  final String? sdpMid;
  final int? sdpMLineIndex;

  const IceCandidate({
    required this.candidate,
    this.sdpMid,
    this.sdpMLineIndex,
  });
}

/// Peer connection state
enum PeerConnectionState {
  idle,
  connecting,
  connected,
  disconnected,
  failed,
  closed,
}

/// Media stream
abstract class MediaStream {
  String get id;

  List<MediaTrack> getTracks();

  Future<void> dispose();
}

/// Media track
abstract class MediaTrack {
  String get id;
  String get kind; // audio | video
  bool get enabled;

  Future<void> setEnabled(bool enabled);

  Future<void> stop();
}

/// Media constraints
class MediaConstraints {
  final bool audio;
  final bool video;

  const MediaConstraints({
    this.audio = true,
    this.video = true,
  });
}

/// Data channel
abstract class DataChannel {
  String get label;

  /// Data stream
  Stream<dynamic> get onMessage;

  /// State stream
  Stream<DataChannelState> get onState;

  /// Send data
  Future<void> send(dynamic data);

  /// Close channel
  Future<void> close();
}

/// Data channel init options
class DataChannelInit {
  final bool ordered;
  final int? maxPacketLifeTime;
  final int? maxRetransmits;

  const DataChannelInit({
    this.ordered = true,
    this.maxPacketLifeTime,
    this.maxRetransmits,
  });
}

/// Data channel state
enum DataChannelState {
  connecting,
  open,
  closing,
  closed,
}
