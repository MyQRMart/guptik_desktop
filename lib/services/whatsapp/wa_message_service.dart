import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:guptik_desktop/models/whatsapp/wa_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
// THIS IS THE MISSING IMPORT
import 'package:path_provider/path_provider.dart'; 

class MessageService {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  // Cache for token to avoid fetching on every image load
  String? _cachedAccessToken;
  DateTime? _tokenExpiry;

  // NEW: Get Access Token for Media Display
  Future<String?> getAccessToken() async {
    // Return cached token if valid (simple cache mechanism)
    if (_cachedAccessToken != null && _tokenExpiry != null && DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedAccessToken;
    }

    final creds = await _getWhatsAppCredentials();
    if (creds != null) {
      _cachedAccessToken = creds['access_token'];
      _tokenExpiry = DateTime.now().add(const Duration(minutes: 50));
      return _cachedAccessToken;
    }
    return null;
  }

  // NEW: Helper to download authenticated media (Video/Audio/Docs)
  Future<File?> downloadAuthenticatedMedia(String url, String fileName) async {
    try {
      final token = await getAccessToken();
      if (token == null) return null;

      final headers = {
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(Uri.parse(url), headers: headers);
      
      if (response.statusCode == 200) {
        // Now this will work because path_provider is imported
        final dir = await getTemporaryDirectory(); 
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file;
      } else {
        debugPrint('Failed to download media: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error downloading media: $e');
      return null;
    }
  }

  // Get WhatsApp credentials
  Future<Map<String, dynamic>?> _getWhatsAppCredentials() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('user_api_settings')
          .select('whatsapp_access_token, meta_wa_phone_number_id, mobile_number')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null || 
          response['whatsapp_access_token'] == null || 
          response['meta_wa_phone_number_id'] == null) {
        debugPrint('Missing WhatsApp credentials');
        return null;
      }

      return {
        'access_token': response['whatsapp_access_token'],
        'phone_number_id': response['meta_wa_phone_number_id'],
        'mobile_number': response['mobile_number'] ?? '',
      };
    } catch (e) {
      debugPrint('Error fetching WhatsApp credentials: $e');
      return null;
    }
  }

  // Get messages for a conversation
  Future<List<Message>> getMessages(
    String conversationId, {
    int limit = 50,
    bool ascending = true,
  }) async {
    try {
      final response = await _supabase
          .from('wa_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('timestamp', ascending: ascending)
          .limit(limit);

      return (response as List)
          .map((json) => Message.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting messages: $e');
      throw Exception('Failed to fetch messages: $e');
    }
  }

  // Send text message
  Future<Message> sendTextMessage({
    required String conversationId,
    required String content,
    required String toPhoneNumber,
    bool isAI = false,
    bool previewUrl = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${userId.substring(0, 8)}';
      final now = DateTime.now().toUtc();
      
      // 1. Insert message to database
      final message = await _supabase
          .from('wa_messages')
          .insert({
            'conversation_id': conversationId,
            'message_id': messageId,
            'content': content,
            'message_type': 'text',
            'direction': isAI ? 'ai_outgoing' : 'outgoing',
            'status': 'pending',
            'timestamp': now.toIso8601String(),
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .select()
          .single();

      debugPrint('Message saved to database with ID: $messageId');

      // 2. Try to send to WhatsApp
      bool whatsappSent = false;
      try {
        whatsappSent = await _sendTextToWhatsApp(
          toPhoneNumber: toPhoneNumber,
          content: content,
          previewUrl: previewUrl,
        );
      } catch (whatsappError) {
        debugPrint('WhatsApp API error: $whatsappError');
        whatsappSent = false;
      }

      // 3. Update status based on WhatsApp result
      final updatedStatus = whatsappSent ? 'sent' : 'failed';
      
      await _supabase
          .from('wa_messages')
          .update({
            'status': updatedStatus,
            'status_timestamp': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('message_id', messageId);

      // 4. Update conversation last message
      await _updateConversationLastMessage(conversationId, content);

      if (!whatsappSent) {
        debugPrint('Warning: Message saved but WhatsApp sending failed');
      }

      return Message.fromJson({
        ...message,
        'status': updatedStatus,
        'status_timestamp': now.toIso8601String(),
      });

    } catch (e) {
      debugPrint('Error in sendTextMessage: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  // Send text to WhatsApp API
  Future<bool> _sendTextToWhatsApp({
    required String toPhoneNumber,
    required String content,
    bool previewUrl = false,
  }) async {
    try {
      final credentials = await _getWhatsAppCredentials();
      if (credentials == null) {
        debugPrint('WhatsApp credentials not configured');
        return false;
      }

      final accessToken = credentials['access_token'];
      final phoneNumberId = credentials['phone_number_id'];
      final cleanPhoneNumber = toPhoneNumber.replaceAll(RegExp(r'[+\s]'), '');

      final url = Uri.parse('https://graph.facebook.com/v23.0/$phoneNumberId/messages');
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

      final requestBody = {
        'messaging_product': 'whatsapp',
        'recipient_type': 'individual',
        'to': cleanPhoneNumber,
        'type': 'text',
        'text': {
          'preview_url': previewUrl,
          'body': content,
        },
      };

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('WhatsApp API Error: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Error in WhatsApp API call: $e');
      return false;
    }
  }

  // Upload media
  Future<Map<String, dynamic>> uploadMedia({
    required String filePath,
    required String fileName,
    String mimeType = 'application/octet-stream',
  }) async {
    try {
      debugPrint('Uploading media: $fileName');
      
      final url = Uri.parse('https://uploadservice.myqrmart.com/upload');
      
      // Create multipart request
      final request = http.MultipartRequest('POST', url);
      
      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: fileName,
        ),
      );

      // Send request
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final responseData = json.decode(responseBody);
        
        // Parse response
        Map<String, dynamic> result;
        if (responseData is List && responseData.isNotEmpty) {
          result = Map<String, dynamic>.from(responseData[0]);
        } else {
          result = Map<String, dynamic>.from(responseData);
        }
        
        if (result['success'] == true || result['success'] == 'true') {
          final fileData = Map<String, dynamic>.from(result['file']);
          final mediaUrl = fileData['url']?.toString() ?? 
                          fileData['browserUrl']?.toString() ??
                          'https://uploadservice.myqrmart.com/u/${fileData['filename']}';
          
          return {
            'success': true,
            'url': mediaUrl,
            'filename': fileData['filename'] ?? fileName,
            'mime_type': fileData['mimetype'] ?? mimeType,
            'size': fileData['size'] ?? await File(filePath).length(),
          };
        } else {
          throw Exception('Upload failed: ${result['message']}');
        }
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error uploading media: $e');
      throw Exception('Failed to upload media: $e');
    }
  }

  // Send media message
  Future<Message> sendMediaMessage({
    required String conversationId,
    required String mediaUrl,
    required String messageType,
    required String toPhoneNumber,
    Map<String, dynamic>? mediaInfo,
    bool isAI = false,
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }
      
      final messageId = 'msg_${DateTime.now().millisecondsSinceEpoch}_${userId.substring(0, 8)}';
      final now = DateTime.now().toUtc();
      
      // Prepare media info
      final Map<String, dynamic> finalMediaInfo = mediaInfo ?? {
        'url': mediaUrl,
        'type': messageType,
        'uploaded_at': now.toIso8601String(),
      };
      
      if (mediaInfo != null) {
        finalMediaInfo.addAll(mediaInfo);
      }

      // 1. Insert to database
      final message = await _supabase
          .from('wa_messages')
          .insert({
            'conversation_id': conversationId,
            'message_id': messageId,
            'content': mediaUrl,
            'message_type': messageType,
            'direction': isAI ? 'ai_outgoing' : 'outgoing',
            'status': 'pending',
            'timestamp': now.toIso8601String(),
            'created_at': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
            'media_info': finalMediaInfo,
          })
          .select()
          .single();

      debugPrint('Media message saved to database');

      // 2. Send to WhatsApp
      bool whatsappSent = false;
      try {
        whatsappSent = await _sendMediaToWhatsApp(
          toPhoneNumber: toPhoneNumber,
          mediaUrl: mediaUrl,
          messageType: messageType,
          mediaInfo: finalMediaInfo,
        );
      } catch (whatsappError) {
        debugPrint('WhatsApp media error: $whatsappError');
        whatsappSent = false;
      }

      // 3. Update status
      final updatedStatus = whatsappSent ? 'sent' : 'failed';
      
      await _supabase
          .from('wa_messages')
          .update({
            'status': updatedStatus,
            'status_timestamp': now.toIso8601String(),
            'updated_at': now.toIso8601String(),
          })
          .eq('message_id', messageId);

      // 4. Update conversation
      final displayMessage = messageType == 'image' ? '📸 Photo' : 
                           messageType == 'video' ? '🎥 Video' : 
                           messageType == 'audio' ? '🎤 Audio' : 
                           '📎 Media';
      
      await _updateConversationLastMessage(conversationId, displayMessage);

      if (!whatsappSent) {
        debugPrint('Warning: Media saved but WhatsApp sending failed');
      }

      return Message.fromJson({
        ...message,
        'status': updatedStatus,
        'status_timestamp': now.toIso8601String(),
      });

    } catch (e) {
      debugPrint('Error in sendMediaMessage: $e');
      throw Exception('Failed to send media message: $e');
    }
  }

  // Send media to WhatsApp API
  Future<bool> _sendMediaToWhatsApp({
    required String toPhoneNumber,
    required String mediaUrl,
    required String messageType,
    Map<String, dynamic>? mediaInfo,
  }) async {
    try {
      final credentials = await _getWhatsAppCredentials();
      if (credentials == null) {
        debugPrint('No WhatsApp credentials for media');
        return false;
      }

      final accessToken = credentials['access_token'];
      final phoneNumberId = credentials['phone_number_id'];
      final cleanPhoneNumber = toPhoneNumber.replaceAll(RegExp(r'[+\s]'), '');

      final url = Uri.parse('https://graph.facebook.com/v23.0/$phoneNumberId/messages');
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $accessToken',
      };

      Map<String, dynamic> requestBody = {
        'messaging_product': 'whatsapp',
        'recipient_type': 'individual',
        'to': cleanPhoneNumber,
        'type': messageType,
      };

      // Add media object based on type
      if (messageType == 'image') {
        requestBody['image'] = {'link': mediaUrl};
      } else if (messageType == 'video') {
        requestBody['video'] = {'link': mediaUrl};
      } else if (messageType == 'audio') {
        requestBody['audio'] = {'link': mediaUrl};
      } else if (messageType == 'document') {
        requestBody['document'] = {
          'link': mediaUrl,
          'filename': mediaInfo?['filename'] ?? 'document',
        };
      }

      final response = await http.post(
        url,
        headers: headers,
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('WhatsApp Media API Error: ${response.body}');
        return false;
    }
    } catch (e) {
      debugPrint('Error in WhatsApp media API: $e');
      return false;
    }
  }

  // Update conversation last message
  Future<void> _updateConversationLastMessage(
    String conversationId,
    String lastMessage,
  ) async {
    try {
      await _supabase
          .from('wa_conversations')
          .update({
            'last_message': lastMessage,
            'last_message_time': DateTime.now().toIso8601String(),
            'is_unread': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', conversationId);
    } catch (e) {
      debugPrint('Error updating conversation: $e');
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String conversationId) async {
    try {
      await _supabase
          .from('wa_messages')
          .update({
            'status': 'read',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('conversation_id', conversationId)
          .eq('direction', 'incoming')
          .eq('status', 'delivered');
    } catch (e) {
      debugPrint('Error marking messages as read: $e');
    }
  }

  // Subscribe to messages stream
  Stream<List<Message>> subscribeToMessages(String conversationId) {
    return Stream.fromFuture(getMessages(conversationId));
  }

  // Delete message
  Future<void> deleteMessage(String messageId) async {
    try {
      await _supabase
          .from('wa_messages')
          .delete()
          .eq('message_id', messageId);
    } catch (e) {
      debugPrint('Error deleting message: $e');
      throw Exception('Failed to delete message: $e');
    }
  }

  // Get unread message count
  Future<int> getUnreadCount(String conversationId) async {
    try {
      final response = await _supabase
          .from('wa_messages')
          .select('id')
          .eq('conversation_id', conversationId)
          .eq('direction', 'incoming')
          .eq('status', 'delivered');

      return response.length;
    } catch (e) {
      debugPrint('Error getting unread count: $e');
      return 0;
    }
  }


  // Check if WhatsApp is configured
  Future<bool> hasWhatsAppConfigured() async {
    final credentials = await _getWhatsAppCredentials();
    return credentials != null && 
           credentials['access_token'] != null && 
           credentials['phone_number_id'] != null;
  }

   
    // Retry failed message
  Future<void> retryFailedMessage(String messageId) async {
    debugPrint('Retry message $messageId - Feature not implemented yet');
  }
}