import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vault_file.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/home.dart';
import '../models/room.dart';
import '../models/board.dart';
import '../models/switch.dart';
import '../models/social_conversation.dart';
import '../models/social_message.dart';
import '../models/auto_comment_post.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();
  SupabaseClient get client => _supabase;
  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

  Future<Map<String, dynamic>?> getUserApiSettings() async {
    try {
      final userId = currentUserId;
      if (userId == null) return null;

      final response = await _supabase
          .from('user_api_settings')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      return response;
    } catch (e) {
      print('Error fetching API settings: $e');
      return null;
    }
  }


  Future<void> registerDesktopDevice({
    required String deviceId, 
    required String userId,
    required String modelName
  }) async {
    try {
      // Upsert: Update if exists, Insert if new
      await _supabase.from('desktop_devices').upsert({
        'device_id': deviceId,
        'user_id': userId,
        'device_model': modelName,
        'status': 'online',
        'last_active_at': DateTime.now().toIso8601String(),
      }, onConflict: 'device_id');
      
      print("Device registered with Supabase: $deviceId");
    } catch (e) {
      throw Exception('Failed to register device: $e');
    }
  }


  // ============== N8N TRIGGER FIX ==============

  Future<void> triggerN8nWebhook(String deviceId) async {
    final webhookUrl = Uri.parse('https://yo.myqrmart.com/webhook/guptik-cf-user-tunnel');
    try {
      print("Attempting to trigger n8n for Device ID: $deviceId");
      
      // FIX: Added 'await' to ensure the request is actually sent before the app navigates
      final response = await http.post(
        webhookUrl,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'device_id': deviceId}),
      );

      if (response.statusCode == 200 || response.statusCode < 300) {
        print("Webhook Triggered Successfully: ${response.statusCode}");
      } else {
        print("Webhook Failed: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print('Webhook trigger exception: $e');
      // Rethrow if you want the UI to handle it, otherwise just logging is fine here
    }
  }

  // ============== VAULT OPERATIONS ==============

  Future<List<VaultFile>> getVaultFiles() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('vault_files')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => VaultFile.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching vault files: $e');
    }
  }

  Future<VaultFile?> getVaultFileById(String id) async {
    try {
      final response = await _supabase
          .from('vault_files')
          .select()
          .eq('id', id)
          .maybeSingle();

      return response != null ? VaultFile.fromJson(response) : null;
    } catch (e) {
      throw Exception('Error fetching vault file: $e');
    }
  }

  Future<VaultFile> addVaultFile(VaultFile file) async {
    try {
      final response = await _supabase
          .from('vault_files')
          .insert(file.toJson())
          .select()
          .single();

      return VaultFile.fromJson(response);
    } catch (e) {
      throw Exception('Error adding vault file: $e');
    }
  }

  // 2. Fetch the updated config from the database
  Future<Map<String, dynamic>?> getTunnelConfig(String deviceId) async {
    try {
      final response = await _supabase
          .from('desktop_devices')
          .select('cf_tunnel_token, public_url, installation_status')
          .eq('device_id', deviceId)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error fetching config: $e');
      return null;
    }
  }

  Future<void> deleteVaultFile(String id) async {
    try {
      await _supabase
          .from('vault_files')
          .delete()
          .eq('id', id);
    } catch (e) {
      throw Exception('Error deleting vault file: $e');
    }
  }

  Future<void> updateVaultFileFavorite(String id, bool isFavorite) async {
    try {
      await _supabase
          .from('vault_files')
          .update({'is_favorite': isFavorite})
          .eq('id', id);
    } catch (e) {
      throw Exception('Error updating vault file: $e');
    }
  }

  // ============== WHATSAPP CONVERSATIONS ==============
  Future<List<Conversation>> getConversations() async {
    try {
      // FIX: Use effective user ID instead of direct auth
      final userId = currentUserId;
      if (userId == null) throw Exception('Device not linked to any user');

      final response = await _supabase
          .from('conversations')
          .select()
          .eq('user_id', userId)
          .order('last_message_time', ascending: false); // Ordered by last message

      return (response as List)
          .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error fetching conversations: $e');
      throw Exception('Error fetching conversations: $e');
    }
  }

  Future<Conversation?> getConversationById(String id) async {
    try {
      final response = await _supabase
          .from('conversations')
          .select()
          .eq('id', id)
          .maybeSingle();

      return response != null ? Conversation.fromJson(response) : null;
    } catch (e) {
      throw Exception('Error fetching conversation: $e');
    }
  }

  // ============== WHATSAPP MESSAGES ==============

  Future<List<Message>> getMessages(String conversationId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('timestamp', ascending: true); // Ordered by timestamp

      return (response as List)
          .map((json) => Message.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching messages: $e');
    }
  }

  Future<Message> createMessage(Message message) async {
    try {
      final response = await _supabase
          .from('messages')
          .insert(message.toJson())
          .select()
          .single();

      return Message.fromJson(response);
    } catch (e) {
      throw Exception('Error creating message: $e');
    }
  }
  // ============== HOME CONTROL - HOMES ==============

  Future<List<Home>> getHomes() async {
    try {
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('hc_homes')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Home.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching homes: $e');
    }
  }

  Future<Home?> getHomeById(String id) async {
    try {
      final response = await _supabase
          .from('hc_homes')
          .select()
          .eq('id', id)
          .maybeSingle();

      return response != null ? Home.fromJson(response) : null;
    } catch (e) {
      throw Exception('Error fetching home: $e');
    }
  }

  Future<Home> createHome(Home home) async {
    try {
      final response = await _supabase
          .from('hc_homes')
          .insert(home.toJson())
          .select()
          .single();

      return Home.fromJson(response);
    } catch (e) {
      throw Exception('Error creating home: $e');
    }
  }

  // ============== HOME CONTROL - ROOMS ==============

  Future<List<Room>> getRoomsForHome(String homeId) async {
    try {
      final response = await _supabase
          .from('hc_rooms')
          .select()
          .eq('home_id', homeId)
          .order('display_order', ascending: true);

      return (response as List)
          .map((json) => Room.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching rooms: $e');
    }
  }

  Future<Room> createRoom(Room room) async {
    try {
      final response = await _supabase
          .from('hc_rooms')
          .insert(room.toJson())
          .select()
          .single();

      return Room.fromJson(response);
    } catch (e) {
      throw Exception('Error creating room: $e');
    }
  }

  // ============== HOME CONTROL - BOARDS ==============

  Future<List<Board>> getBoardsForHome(String homeId) async {
    try {
      final response = await _supabase
          .from('hc_boards')
          .select()
          .eq('home_id', homeId);

      return (response as List)
          .map((json) => Board.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching boards: $e');
    }
  }

  Future<Board> createBoard(Board board) async {
    try {
      final response = await _supabase
          .from('hc_boards')
          .insert(board.toJson())
          .select()
          .single();

      return Board.fromJson(response);
    } catch (e) {
      throw Exception('Error creating board: $e');
    }
  }

  Future<Board?> getBoardById(String id) async {
    try {
      final response = await _supabase
          .from('hc_boards')
          .select()
          .eq('id', id)
          .maybeSingle();

      return response != null ? Board.fromJson(response) : null;
    } catch (e) {
      throw Exception('Error fetching board: $e');
    }
  }

  // ============== HOME CONTROL - SWITCHES ==============

  Future<List<Switch>> getSwitchesForBoard(String boardId) async {
    try {
      final response = await _supabase
          .from('hc_switches')
          .select()
          .eq('board_id', boardId)
          .order('position', ascending: true);

      return (response as List)
          .map((json) => Switch.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error fetching switches: $e');
    }
  }

  Future<void> updateSwitchState(String switchId, bool newState) async {
    try {
      await _supabase
          .from('hc_switches')
          .update({
            'state': newState,
            'last_state_change': DateTime.now().toIso8601String(),
          })
          .eq('id', switchId);
    } catch (e) {
      throw Exception('Error updating switch state: $e');
    }
  }

  Future<Switch> createSwitch(Switch switchItem) async {
    try {
      final response = await _supabase
          .from('hc_switches')
          .insert(switchItem.toJson())
          .select()
          .single();

      return Switch.fromJson(response);
    } catch (e) {
      throw Exception('Error creating switch: $e');
    }
  }

  Future<List<SocialConversation>> getSocialConversations(String platformPrefix) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final response = await _supabase
        .from('${platformPrefix}_conversations')
        .select()
        .eq('user_id', userId)
        .order('last_message_time', ascending: false);

    return (response as List).map((json) => SocialConversation.fromJson(json)).toList();
  }

  Future<List<SocialMessage>> getSocialMessages(String platformPrefix, String conversationId) async {
    final response = await _supabase
        .from('${platformPrefix}_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('timestamp', ascending: true);

    return (response as List).map((json) => SocialMessage.fromJson(json)).toList();
  }

  Future<List<AutoCommentPost>> getAutoComments(String platformPrefix) async {
    final userId = currentUserId;
    if (userId == null) return [];

    final response = await _supabase
        .from('${platformPrefix}_auto_comment_posts')
        .select()
        .eq('user_id', userId);

    return (response as List).map((json) => AutoCommentPost.fromJson(json)).toList();
  }

  Future<void> updateUserApiSettings(Map<String, dynamic> updates) async {
    final userId = currentUserId;
    if (userId == null) return;

    await _supabase
        .from('user_api_settings')
        .update(updates)
        .eq('user_id', userId);
  }


  Future<bool> verifyDeviceRegistration(String userId, String deviceModel) async {
    try {
      final response = await _supabase
          .from('desktop_devices')
          .select('id')
          .eq('user_id', userId)
          .eq('device_model', deviceModel)
          .limit(1);
          
      return (response as List).isNotEmpty;
    } catch (e) {
      print('Error verifying device: $e');
      return false;
    }
  }

  // ============== GET STABLE DEVICE ID ==============
  Future<String> getOrCreateDeviceId() async {
    // Stop using SharedPreferences/UUIDs. 
    // Return the stable computer hostname so it survives preference clears.
    return Platform.localHostname;
  }

    

















}





