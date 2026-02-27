import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:guptik_desktop/models/whatsapp/wa_conversation.dart'; // Ensure this matches your package name
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConversationService {
  final SupabaseClient _client = Supabase.instance.client;
  String? get _userId => _client.auth.currentUser?.id;

  // Helper: Get the correct User ID (Auth or Device-Linked)
  Future<String?> _getEffectiveUserId() async {
    // 1. Check if explicitly logged in via Supabase Auth
    if (_client.auth.currentUser?.id != null) {
      return _client.auth.currentUser!.id;
    }

    // 2. Fallback: Resolve via Device ID
    try {
      final prefs = await SharedPreferences.getInstance();
      // Check both keys just in case
      final deviceId = prefs.getString('device_id') ?? prefs.getString('desktop_device_id');
      
      if (deviceId != null) {
        debugPrint('Resolving User ID for Device: $deviceId');
        final response = await _client
            .from('desktop_devices')
            .select('user_id')
            .eq('device_id', deviceId)
            .maybeSingle();
        
        if (response != null && response['user_id'] != null) {
          final userId = response['user_id'] as String;
          debugPrint('Resolved User ID: $userId');
          return userId;
        }
      }
    } catch (e) {
      debugPrint('Error resolving User ID: $e');
    }
    return null;
  }

  // Helper to get current UTC timestamp in ISO format
  String _getUtcTimestamp() {
    return DateTime.now().toUtc().toIso8601String();
  }

  Future<List<Conversation>> getConversations() async {
    try {
      debugPrint('Fetching all conversations...');
      
      final userId = await _getEffectiveUserId();
      if (userId == null) {
        debugPrint('Aborting: No User ID linked to this device.');
        return [];
      }

      final data = await _client
          .from('wa_conversations')
          .select()
          .eq('user_id', _userId!) // Filter by the resolved User ID
          .order('last_message_time', ascending: false);
          
      debugPrint('Fetched ${data.length} conversations');
      return (data as List)
          .map((item) {
            try {
              return Conversation.fromMap(item) ;
            } catch (e) {
              debugPrint('Error parsing conversation item: $e');
              // debugPrint('Stack: $stack');
              rethrow;
            }
          })
          .toList();
    } catch (e) {
      debugPrint('Error in getConversations: $e');
      // Return empty list instead of throwing to prevent UI crash
      return []; 
    }
  }

  Future<List<Conversation>> getIndividualConversations() async {
    try {
      debugPrint('Fetching individual conversations...');
      
      final userId = await _getEffectiveUserId();
      if (userId == null) return [];

      final data = await _client
          .from('wa_conversations')
          .select()
          .eq('user_id', userId) // Filter by User ID
          .eq('is_archived', false)
          .order('last_message_time', ascending: false);
          
      debugPrint('Fetched ${data.length} individual conversations');
      return (data as List)
          .map((item) => Conversation.fromMap(item))
          .toList();
    } catch (e) {
      debugPrint('Error in getIndividualConversations: $e');
      return [];
    }
  }

  Future<List<Conversation>> getGroupConversations() async {
    try {
      debugPrint('Fetching group conversations...');
      
      final userId = await _getEffectiveUserId();
      if (userId == null) return [];

      final data = await _client
          .from('conversations')
          .select()
          .eq('user_id', userId) // Filter by User ID
          .eq('is_archived', false)
          .filter('ai_agent_id', 'not.is', null)
          .order('last_message_time', ascending: false);
          
      debugPrint('Fetched ${data.length} group conversations');
      return (data as List)
          .map((item) => Conversation.fromMap(item))
          .toList();
    } catch (e) {
      debugPrint('Error in getGroupConversations: $e');
      return [];
    }
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      await _client
          .from('wa_conversations')
          .update({
            'is_unread': false, 
            'updated_at': _getUtcTimestamp()
          })
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> updateLastMessage({
    required String conversationId,
    required String message,
    bool fromUser = true,
  }) async {
    try {
      final currentTime = DateTime.now();
      final utcTime = currentTime.toUtc().toIso8601String();
      final localTimeForText = currentTime.toIso8601String();
      
      await _client
          .from('wa_conversations')
          .update({
            'last_message': message,
            'last_message_time': localTimeForText,
            'updated_at': utcTime,
            'is_unread': fromUser,
          })
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('Error updating last message: $e');
    }
  }

  Future<void> updateAIAgentStatus({
    required String conversationId,
    required bool aiEnabled,
    String defaultAgentId = '00000000-0000-0000-0000-000000000000',
  }) async {
    try {
      await _client
        .from('wa_conversations')
        .update({
          'ai_agent_id': aiEnabled ? defaultAgentId : null,
          'updated_at': _getUtcTimestamp(),
        })
        .eq('id', conversationId);
    } catch (e) {
      debugPrint('Error updating AI agent status: $e');
    }
  }
  
  Future<bool> getAIAgentStatus(String conversationId) async {
    try {
      final response = await _client
        .from('wa_conversations')
        .select('ai_agent_id')
        .eq('id', conversationId)
        .single();
      
      return response['ai_agent_id'] != null;
    } catch (e) {
      return false;
    }
  }

  Future<Conversation?> getConversationById(String conversationId) async {
    try {
      final response = await _client
        .from('wa_conversations')
        .select()
        .eq('id', conversationId)
        .single();
      
      return Conversation.fromMap(response);
    } catch (e) {
      debugPrint('Error getting conversation by ID: $e');
      return null;
    }
  }
}