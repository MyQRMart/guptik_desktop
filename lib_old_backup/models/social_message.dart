class SocialMessage {
  final String id;
  final String conversationId;
  final String content;
  final String direction;
  final String timestamp;

  SocialMessage({
    required this.id,
    required this.conversationId,
    required this.content,
    required this.direction,
    required this.timestamp,
  });

  factory SocialMessage.fromJson(Map<String, dynamic> json) {
    return SocialMessage(
      id: json['id'],
      conversationId: json['conversation_id'],
      content: json['content'],
      direction: json['direction'],
      timestamp: json['timestamp'],
    );
  }
}