import 'package:uuid/uuid.dart';

class Message {
  final String id;
  final String conversationId;
  final String messageId;
  final String content;
  final String messageType; // text, image, video, audio, document, location, contacts, sticker, reaction
  final String direction; // incoming, outgoing, ai_outgoing
  final String? status; // sent, delivered, read, failed, pending
  final String timestamp;
  final String? statusTimestamp;
  final String? templateId;
  final Map<String, dynamic>? mediaInfo;
  final Map<String, dynamic>? rawData;
  final DateTime createdAt;
  final DateTime updatedAt;

  Message({
    String? id,
    required this.conversationId,
    required this.messageId,
    required this.content,
    this.messageType = 'text',
    required this.direction,
    this.status,
    required this.timestamp,
    this.statusTimestamp,
    this.templateId,
    this.mediaInfo,
    this.rawData,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      messageId: json['message_id'] as String,
      content: json['content'] as String,
      messageType: json['message_type'] as String? ?? 'text',
      direction: json['direction'] as String,
      status: json['status'] as String?,
      timestamp: json['timestamp'] as String,
      statusTimestamp: json['status_timestamp'] as String?,
      templateId: json['template_id'] as String?,
      mediaInfo: json['media_info'] as Map<String, dynamic>?,
      rawData: json['raw_data'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : DateTime.now(),
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'conversation_id': conversationId,
      'message_id': messageId,
      'content': content,
      'message_type': messageType,
      'direction': direction,
      'status': status,
      'timestamp': timestamp,
      'status_timestamp': statusTimestamp,
      'template_id': templateId,
      'media_info': mediaInfo,
      'raw_data': rawData,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isOutgoing => direction == 'outgoing' || direction == 'ai_outgoing';
  bool get isIncoming => direction == 'incoming';
}
