import 'dart:convert';
import 'package:flutter/foundation.dart';

class Message {
  final String id;
  final String conversationId;
  final String messageId;
  final String content;
  final String messageType;
  final String direction; // 'incoming', 'outgoing', 'ai_outgoing'
  final String? status;
  final DateTime timestamp;
  final DateTime? statusTimestamp;
  final String? templateId;
  final Map<String, dynamic>? mediaInfo;
  final dynamic rawData;
  final DateTime createdAt;
  final DateTime updatedAt;

  Message({
    required this.id,
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
    required this.createdAt,
    required this.updatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversation_id']?.toString() ?? '',
      messageId: json['message_id']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      messageType: json['message_type']?.toString() ?? 'text',
      direction: json['direction']?.toString() ?? '',
      status: json['status']?.toString(),
      timestamp: _parseDateTime(json['timestamp']),
      statusTimestamp: json['status_timestamp'] != null
          ? _parseDateTime(json['status_timestamp'])
          : null,
      templateId: json['template_id']?.toString(),
      mediaInfo: _parseMediaInfo(json['media_info']),
      rawData: json['raw_data'],
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  // FIXED: Handle flexible media info parsing
  static Map<String, dynamic>? _parseMediaInfo(dynamic field) {
    if (field == null) return null;
    
    if (field is Map) {
      return Map<String, dynamic>.from(field);
    }
    
    if (field is String) {
      try {
        final parsed = json.decode(field);
        if (parsed is Map) {
          return Map<String, dynamic>.from(parsed);
        }
        return {'mime_type': parsed.toString()}; 
      } catch (e) {
        return {'mime_type': field};
      }
    }
    return null;
  }

  // FIXED: Handle Postgres space vs 'T' in ISO dates
  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now().toLocal();
    try {
      String dateString = value.toString().trim();
      
      // Fix Postgres format by replacing space with T if T is missing
      if (dateString.contains(' ') && !dateString.contains('T')) {
        dateString = dateString.replaceFirst(' ', 'T');
      }

      // Append Z if no timezone info exists
      if (!dateString.endsWith('Z') && 
          !dateString.contains('+') && 
          !dateString.contains('-')) {
        dateString = '${dateString}Z';
      }
      return DateTime.parse(dateString).toLocal();
    } catch (e) {
      debugPrint("Error parsing message date: $value - $e");
      return DateTime.now().toLocal();
    }
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
      'timestamp': timestamp.toUtc().toIso8601String(),
      'status_timestamp': statusTimestamp?.toUtc().toIso8601String(),
      'template_id': templateId,
      'media_info': mediaInfo,
      'raw_data': rawData,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  // Helpers
  bool get isIncoming => direction == 'incoming';
  bool get isOutgoing => direction == 'outgoing';
  bool get isAiOutgoing => direction == 'ai_outgoing';
  bool get hasMedia => mediaInfo != null && mediaInfo!.isNotEmpty;
  
  // Time Formatting
  String get formattedTime => '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  
  String get formattedDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) return 'Today';
    return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}';
  }
}