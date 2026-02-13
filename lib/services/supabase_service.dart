import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/vault_file.dart';
import '../models/conversation.dart';
import '../models/message.dart';
import '../models/home.dart';
import '../models/room.dart';
import '../models/board.dart';
import '../models/switch.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  SupabaseClient get client => _supabase;

  final SupabaseClient _supabase = Supabase.instance.client;

  String? get currentUserId => _supabase.auth.currentUser?.id;

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

  Future<void> triggerTunnelProvisioning(String deviceId) async {
    try {
      // Calling the function you just deployed to project 'vyujytsdtdmdjlrvglel'
      await _supabase.functions.invoke('user-cf-tunnel', body: {
        'user_id': _supabase.auth.currentUser!.id,
        'device_id': deviceId,
      });
    } catch (e) {
      print("Cloudflare Provisioning Error: $e");
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

  Future<String?> provisionUserTunnel(String deviceId) async {
    try {
      final response = await _supabase.functions.invoke(
        'user-cf-tunnel',
        body: {
          'user_id': currentUserId,
          'device_id': deviceId,
        },
      );
      
      // Returns the token if successful
      if (response.status == 200) {
        return response.data['cf_tunnel_token'];
      }
      return null;
    } catch (e) {
      print("Edge Function Error: $e");
      return null;
    }
  }

  Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? deviceId = prefs.getString('desktop_device_id');
    
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await prefs.setString('desktop_device_id', deviceId);
    }
    return deviceId;
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
      final userId = currentUserId;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('conversations')
          .select()
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      return (response as List)
          .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
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

  Future<Conversation> createConversation(Conversation conversation) async {
    try {
      final response = await _supabase
          .from('conversations')
          .insert(conversation.toJson())
          .select()
          .single();

      return Conversation.fromJson(response);
    } catch (e) {
      throw Exception('Error creating conversation: $e');
    }
  }

  Future<void> updateConversation(String id, Map<String, dynamic> updates) async {
    try {
      await _supabase
          .from('conversations')
          .update(updates)
          .eq('id', id);
    } catch (e) {
      throw Exception('Error updating conversation: $e');
    }
  }

  // ============== WHATSAPP MESSAGES ==============

  Future<List<Message>> getMessages(String conversationId) async {
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

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

  Future<void> updateMessageStatus(String id, String status) async {
    try {
      await _supabase
          .from('messages')
          .update({'status': status})
          .eq('id', id);
    } catch (e) {
      throw Exception('Error updating message status: $e');
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
}
