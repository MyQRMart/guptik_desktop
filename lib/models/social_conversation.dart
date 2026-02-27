class SocialConversation {
  final String id;
  final String userId;
  final String? lastMessage;
  final String lastMessageTime;
  final bool isUnread;
  final String? senderId;

  SocialConversation({
    required this.id,
    required this.userId,
    this.lastMessage,
    required this.lastMessageTime,
    required this.isUnread,
    this.senderId,
  });

  factory SocialConversation.fromJson(Map<String, dynamic> json) {
    return SocialConversation(
      id: json['id'],
      userId: json['user_id'],
      lastMessage: json['last_message'],
      lastMessageTime: json['last_message_time'],
      isUnread: json['is_unread'] ?? false,
      senderId: json['sender_id'],
    );
  }
}