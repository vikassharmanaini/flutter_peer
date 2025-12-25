library signaling_protocol;

enum SignalingMessageType {
  open,
  error,
  idTaken,
  invalidId,
  offer,
  answer,
  candidate,
  leave,
  expire,
}

class SignalingMessage {
  final SignalingMessageType type;
  final String? src;
  final String? dst;
  final dynamic payload;

  SignalingMessage({required this.type, this.src, this.dst, this.payload});

  Map<String, dynamic> toJson() {
    return {
      'type': type.name.toUpperCase(),
      if (src != null) 'src': src,
      if (dst != null) 'dst': dst,
      if (payload != null) 'payload': payload,
    };
  }

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: SignalingMessageType.values.firstWhere(
        (e) => e.name.toUpperCase() == json['type'],
        orElse: () => SignalingMessageType.error,
      ),
      src: json['src'],
      dst: json['dst'],
      payload: json['payload'],
    );
  }
}
