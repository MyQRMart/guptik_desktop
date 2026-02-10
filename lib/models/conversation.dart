import 'package:uuid/uuid.dart';

class Conversation {
  final String id;
  final String userId;
  final String? aiAgentId;
  final String phoneNumber;
  final String? contactName;
  final String? contactEmail;
  final String? contactNotes;
  final String? lastMessage;
  final String lastMessageTime;
  final bool isUnread;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    String? id,
    required this.userId,
    this.aiAgentId,
    required this.phoneNumber,
    this.contactName,
    this.contactEmail,
    this.contactNotes,
    this.lastMessage,
    required this.lastMessageTime,
    this.isUnread = true,
    this.isArchived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      aiAgentId: json['ai_agent_id'] as String?,
      phoneNumber: json['phone_number'] as String,
      contactName: json['contact_name'] as String?,
      contactEmail: json['contact_email'] as String?,
      contactNotes: json['contact_notes'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageTime: json['last_message_time'] as String? ?? DateTime.now().toIso8601String(),
      isUnread: (json['is_unread'] as bool?) ?? true,
      isArchived: (json['is_archived'] as bool?) ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'ai_agent_id': aiAgentId,
      'phone_number': phoneNumber,
      'contact_name': contactName,
      'contact_email': contactEmail,
      'contact_notes': contactNotes,
      'last_message': lastMessage,
      'last_message_time': lastMessageTime,
      'is_unread': isUnread,
      'is_archived': isArchived,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Conversation copyWith({
    String? id,
    String? userId,
    String? aiAgentId,
    String? phoneNumber,
    String? contactName,
    String? contactEmail,
    String? contactNotes,
    String? lastMessage,
    String? lastMessageTime,
    bool? isUnread,
    bool? isArchived,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      aiAgentId: aiAgentId ?? this.aiAgentId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      contactName: contactName ?? this.contactName,
      contactEmail: contactEmail ?? this.contactEmail,
      contactNotes: contactNotes ?? this.contactNotes,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      isUnread: isUnread ?? this.isUnread,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
