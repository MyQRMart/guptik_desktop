import 'package:flutter/material.dart';
import 'package:guptik_desktop/models/whatsapp/wa_conversation.dart';
import 'package:guptik_desktop/services/node/node_table_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guptik_desktop/services/admin/admin_shim.dart';

class ConversationService {
  final SupabaseClient _client = Supabase.instance.client;
  final _store = NodeTableClient();

  Future<String?> _getEffectiveUserId() async {
    if (_client.auth.currentUser?.id != null) {
      return _client.auth.currentUser!.id;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id') ?? prefs.getString('desktop_device_id');
      if (deviceId != null) {
        final response = await _client
            .from('desktop_devices')
            .select('user_id')
            .eq('device_id', deviceId)
            .maybeSingle();
        if (response != null && response['user_id'] != null) {
          return response['user_id'] as String;
        }
      }
    } catch (e) {
      debugPrint('Error resolving User ID: $e');
    }
    return null;
  }

  String _getUtcTimestamp() => DateTime.now().toUtc().toIso8601String();

  Future<List<Conversation>> getConversations() async {
    final userId = await _getEffectiveUserId();
    if (userId == null) return [];
    final data = await _store.select(
      'wa_conversations',
      eq: {'user_id': userId},
      order: 'last_message_time',
      ascending: false,
    );
    return data.map(Conversation.fromMap).toList();
  }

  Future<List<Conversation>> getIndividualConversations() async {
    final userId = await _getEffectiveUserId();
    if (userId == null) return [];
    final data = await _store.select(
      'wa_conversations',
      eq: {'user_id': userId, 'is_archived': 'false'},
      order: 'last_message_time',
      ascending: false,
    );
    return data.map(Conversation.fromMap).toList();
  }

  Future<List<Conversation>> getGroupConversations() async {
    final userId = await _getEffectiveUserId();
    if (userId == null) return [];
    final data = await _store.select(
      'conversations',
      eq: {'user_id': userId, 'is_archived': 'false'},
      notNull: 'ai_agent_id',
      order: 'last_message_time',
      ascending: false,
    );
    return data.map(Conversation.fromMap).toList();
  }

  Future<void> markAsRead(String conversationId) async {
    await _store.update(
      'wa_conversations',
      eq: {'id': conversationId},
      set: {'is_unread': false, 'updated_at': _getUtcTimestamp()},
    );
  }

  Future<void> updateLastMessage({
    required String conversationId,
    required String message,
    bool fromUser = true,
  }) async {
    final currentTime = DateTime.now();
    await _store.update(
      'wa_conversations',
      eq: {'id': conversationId},
      set: {
        'last_message': message,
        'last_message_time': currentTime.toIso8601String(),
        'updated_at': currentTime.toUtc().toIso8601String(),
        'is_unread': fromUser,
      },
    );
  }

  Future<void> updateAIAgentStatus({
    required String conversationId,
    required bool aiEnabled,
    String defaultAgentId = '00000000-0000-0000-0000-000000000000',
  }) async {
    await _store.update(
      'wa_conversations',
      eq: {'id': conversationId},
      set: {
        'ai_agent_id': aiEnabled ? defaultAgentId : null,
        'updated_at': _getUtcTimestamp(),
      },
    );
  }

  Future<bool> getAIAgentStatus(String conversationId) async {
    final row = await _store.maybeSingle('wa_conversations', {'id': conversationId});
    return row?['ai_agent_id'] != null;
  }

  Future<Conversation?> getConversationById(String conversationId) async {
    final row = await _store.maybeSingle('wa_conversations', {'id': conversationId});
    if (row == null) return null;
    return Conversation.fromMap(row);
  }
}
