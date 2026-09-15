import 'package:flutter/foundation.dart';

enum ConversationStatus { active, closed }

class Conversation {
  final String id;
  final String userId;
  final String? aiAgentId;
  final String phoneNumber;
  final String? contactName;
  final String? contactEmail;
  final String? contactNotes;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final bool isUnread;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ConversationStatus status;

  Conversation({
    required this.id,
    required this.userId,
    this.aiAgentId,
    required this.phoneNumber,
    this.contactName,
    this.contactEmail,
    this.contactNotes,
    this.lastMessage,
    this.lastMessageTime,
    required this.isUnread,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      id: (map['id'] as String?) ?? '',
      userId: (map['user_id'] as String?) ?? '',
      aiAgentId: map['ai_agent_id'] as String?,
      phoneNumber: (map['phone_number'] as String?) ?? '',
      contactName: map['contact_name'] as String?,
      contactEmail: map['contact_email'] as String?,
      contactNotes: map['contact_notes'] as String?,
      lastMessage: map['last_message'] as String?,
      // FIXED: robust date parsing
      lastMessageTime: _safeParseDateTime(map['last_message_time']),
      isUnread: (map['is_unread'] as bool?) ?? true,
      isArchived: (map['is_archived'] as bool?) ?? false,
      createdAt: _safeParseDateTime(map['created_at']) ?? DateTime.now().toLocal(),
      updatedAt: _safeParseDateTime(map['updated_at']) ?? DateTime.now().toLocal(),
      status: _parseStatus(map['status']),
    );
  }

  static DateTime? _safeParseDateTime(dynamic value) {
    if (value == null) return null;
    
    try {
      String dateStr = value.toString();
      // Fix Postgres format "2026-01-28 04:05:12" -> "2026-01-28T04:05:12"
      if (dateStr.contains(' ') && !dateStr.contains('T')) {
        dateStr = dateStr.replaceFirst(' ', 'T');
      }
      return DateTime.parse(dateStr).toLocal();
    } catch (e) {
      if (kDebugMode) {
        print('Error parsing datetime: $value, error: $e');
      }
      return null;
    }
  }

  static ConversationStatus _parseStatus(dynamic value) {
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'active':
          return ConversationStatus.active;
        case 'closed':
          return ConversationStatus.closed;
      }
    }
    return ConversationStatus.active;
  }

  // Computed properties for UI compatibility
  bool get isGroup => aiAgentId != null;

  String get initials {
    if (contactName != null && contactName!.trim().isNotEmpty) {
      final parts = contactName!.trim().split(' ');
      if (parts.length >= 2) {
        return (parts[0][0] + parts[1][0]).toUpperCase();
      } else {
        return parts[0][0].toUpperCase();
      }
    }
    return phoneNumber.isNotEmpty ? phoneNumber[0].toUpperCase() : '?';
  }

  String get displayName => contactName?.isNotEmpty == true ? contactName! : phoneNumber;
  
  DateTime get timestamp => lastMessageTime ?? createdAt;
}