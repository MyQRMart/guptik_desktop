import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:guptik_desktop/models/whatsapp/wa_conversation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConversationService {
  final SupabaseClient _client = Supabase.instance.client;

  // Helper to get current UTC timestamp in ISO format
  String _getUtcTimestamp() {
    return DateTime.now().toUtc().toIso8601String();
  }

  Future<List<Conversation>> getConversations() async {
    try {
      debugPrint('Fetching all conversations...');
      final data = await _client
          .from('conversations')
          .select()
          .order('last_message_time', ascending: false);
          
      debugPrint('Fetched ${data.length} conversations');
      return (data as List)
          .map((item) {
            try {
              return Conversation.fromMap(item);
            } catch (e, stack) {
              debugPrint('Error parsing conversation item: $e');
              debugPrint('Stack: $stack');
              debugPrint('Item data: ${jsonEncode(item)}');
              rethrow;
            }
          })
          .toList();
    } catch (e) {
      debugPrint('Error in getConversations: $e');
      throw Exception('Failed to fetch conversations: $e');
    }
  }

  Future<List<Conversation>> getIndividualConversations() async {
    try {
      debugPrint('Fetching individual conversations...');
      final data = await _client
          .from('conversations')
          .select()
          .eq('is_archived', false)
          .order('last_message_time', ascending: false);
          
      debugPrint('Fetched ${data.length} individual conversations');
      return (data as List)
          .map((item) => Conversation.fromMap(item))
          .toList();
    } catch (e) {
      debugPrint('Error in getIndividualConversations: $e');
      throw Exception('Failed to fetch individual conversations: $e');
    }
  }

  Future<List<Conversation>> getGroupConversations() async {
    try {
      debugPrint('Fetching group conversations...');
      final data = await _client
          .from('conversations')
          .select()
          .eq('is_archived', false)
          .filter('ai_agent_id', 'not.is', null)
          .order('last_message_time', ascending: false);
          
      debugPrint('Fetched ${data.length} group conversations');
      return (data as List)
          .map((item) => Conversation.fromMap(item))
          .toList();
    } catch (e) {
      debugPrint('Error in getGroupConversations: $e');
      throw Exception('Failed to fetch group conversations: $e');
    }
  }

  Future<void> markAsRead(String conversationId) async {
    try {
      debugPrint('Marking conversation $conversationId as read');
      await _client
          .from('conversations')
          .update({
            'is_unread': false, 
            'updated_at': _getUtcTimestamp()
          })
          .eq('id', conversationId);
      debugPrint('Successfully marked as read');
    } catch (e) {
      debugPrint('Error marking as read: $e');
      throw Exception('Failed to mark conversation as read: $e');
    }
  }

  Future<void> updateLastMessage({
    required String conversationId,
    required String message,
    bool fromUser = true,
  }) async {
    try {
      debugPrint('Updating last message for conversation $conversationId');
      
      final currentTime = DateTime.now();
      final utcTime = currentTime.toUtc().toIso8601String();
      final localTimeForText = currentTime.toIso8601String();
      
      await _client
          .from('conversations')
          .update({
            'last_message': message,
            'last_message_time': localTimeForText,
            'updated_at': utcTime,
            'is_unread': fromUser,
          })
          .eq('id', conversationId);
          
      debugPrint('Successfully updated last message');
    } catch (e) {
      debugPrint('Error updating last message: $e');
      throw Exception('Failed to update last message: $e');
    }
  }

  Future<void> updateAIAgentStatus({
    required String conversationId,
    required bool aiEnabled,
    String defaultAgentId = '00000000-0000-0000-0000-000000000000',
  }) async {
    try {
      debugPrint('Updating AI agent status for $conversationId to $aiEnabled');
      await _client
        .from('conversations')
        .update({
          'ai_agent_id': aiEnabled ? defaultAgentId : null,
          'updated_at': _getUtcTimestamp(),
        })
        .eq('id', conversationId);
      debugPrint('Successfully updated AI agent status');
    } catch (e) {
      debugPrint('Error updating AI agent status: $e');
      throw Exception('Failed to update AI agent status: $e');
    }
  }
  
  Future<bool> getAIAgentStatus(String conversationId) async {
    try {
      debugPrint('Getting AI agent status for $conversationId');
      final response = await _client
        .from('conversations')
        .select('ai_agent_id')
        .eq('id', conversationId)
        .single();
      
      final hasAgent = response['ai_agent_id'] != null;
      debugPrint('AI agent status: $hasAgent');
      return hasAgent;
    } catch (e) {
      debugPrint('Error getting AI agent status: $e');
      return false;
    }
  }

  Future<Conversation> getConversationById(String conversationId) async {
    try {
      debugPrint('Getting conversation by ID: $conversationId');
      final response = await _client
        .from('conversations')
        .select()
        .eq('id', conversationId)
        .single();
      
      return Conversation.fromMap(response);
    } catch (e) {
      debugPrint('Error getting conversation by ID: $e');
      throw Exception('Failed to get conversation: $e');
    }
  }

  // Optional: Search conversations by phone or name
  // Future<List<Conversation>> searchConversations(String query) async {
  //   try {
  //     debugPrint('Searching conversations for: $query');
  //     final data = await _client
  //         .from('conversations')
  //         .select()
  //         .or('phone_number.ilike.%$query%,contact_name.ilike.%$query%')
  //         .order('last_message_time', ascending: false);
          
  //     debugPrint('Found ${data.length} conversations');
  //     return (data as List)
  //         .map((item) => Conversation.fromMap(item))
  //         .toList();
  //   } catch (e) {
  //     debugPrint('Error searching conversations: $e');
  //     return [];
  //   }
  // }

  // Optional: Get unread count for badge
  // Future<int> getUnreadCount() async {
  //   try {
  //     final data = await _client
  //         .from('conversations')
  //         .select('id', count: CountOption.exact)
  //         .eq('is_unread', true)
  //         .eq('is_archived', false);
      
  //     final count = data.length;
  //     debugPrint('Unread conversations count: $count');
  //     return count;
  //   } catch (e) {
  //     debugPrint('Error getting unread count: $e');
  //     return 0;
  //   }
  // }

  // // Optional: Archive/Unarchive conversation
  // Future<void> toggleArchive(String conversationId, {bool archive = true}) async {
  //   try {
  //     debugPrint('${archive ? 'Archiving' : 'Unarchiving'} conversation $conversationId');
  //     await _client
  //       .from('conversations')
  //       .update({
  //         'is_archived': archive,
  //         'updated_at': _getUtcTimestamp(),
  //       })
  //       .eq('id', conversationId);
  //     debugPrint('Successfully ${archive ? 'archived' : 'unarchived'} conversation');
  //   } catch (e) {
  //     debugPrint('Error toggling archive: $e');
  //     throw Exception('Failed to ${archive ? 'archive' : 'unarchive'} conversation: $e');
  //   }
  // }
}