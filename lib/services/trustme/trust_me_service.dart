import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';

class TrustMeService {
  static TrustMeService? _instance;
  static TrustMeService get instance => _instance ??= TrustMeService._();
  TrustMeService._();

  WebSocketChannel? _wsChannel;
  final _listeners = <String, List<Function(Map<String, dynamic>)>>{};

  // Connects to your local Docker Gateway
  String get _gatewayUrl => 'http://localhost:55000';

  // FIXED: String interpolation warning
  String get _wsUrl => '${_gatewayUrl.replaceFirst('http', 'ws')}/ws';

  // ─── WebSocket Connection ──────────────────────────────────────────────
  Future<void> connect() async {
    _wsChannel = WebSocketChannel.connect(Uri.parse(_wsUrl));
    _wsChannel!.stream.listen(
      (message) {
        final event = jsonDecode(message as String) as Map<String, dynamic>;
        final type = event['type'] as String?;
        if (type != null) {
          _listeners[type]?.forEach((cb) => cb(event));
          _listeners['*']?.forEach((cb) => cb(event));
        }
      },
      // FIXED: Nullable return type warning
      onDone: () {
        Future.delayed(const Duration(seconds: 5), connect);
      },
    );
  }

  // ─── Handshake ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> generateHandshakeCode(
    String targetUsername,
  ) async {
    final response = await http.post(
      Uri.parse('$_gatewayUrl/internal/handshake/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'target_username': targetUsername}),
    );

    // FIXED: Curly braces in flow control warning
    if (response.statusCode != 200) {
      throw Exception("Generation failed: ${response.body}");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> enterHandshakeCode({
    required String code,
    required String sessionId,
  }) async {
    final response = await http.post(
      Uri.parse('$_gatewayUrl/internal/handshake/enter'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'code': code, 'session_id': sessionId}),
    );

    // FIXED: Curly braces in flow control warning
    if (response.statusCode != 200) {
      throw Exception("Invalid code or session expired.");
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getPendingRequests() async {
    final response = await http.get(
      Uri.parse('$_gatewayUrl/internal/handshake/pending'),
    );

    if (response.statusCode == 404) {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['pending'] as List).cast<Map<String, dynamic>>();
  }

  // ─── Conversations (RESTORED MISSING METHOD) ───────────────────────────
  Future<List<ConversationSummary>> getConversations() async {
    final response = await http.get(
      Uri.parse('$_gatewayUrl/internal/conversations'),
    );

    if (response.statusCode == 404) {
      return [];
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return (data['conversations'] as List)
        .map((c) => ConversationSummary.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  // ─── Messaging ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String content,
    String contentType = 'text',
  }) async {
    final response = await http.post(
      Uri.parse('$_gatewayUrl/internal/message/send'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'conversation_id': conversationId,
        'content': content,
        'content_type': contentType,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }
}

// ─── RESTORED MISSING DATA MODELS ──────────────────────────────────────────

class ConversationSummary {
  final String id;
  final String type;
  final String? contactUsername;
  final String? lastMessagePreview;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final bool isOnline;
  final bool isPinned;
  final bool isMuted;

  ConversationSummary({
    required this.id,
    required this.type,
    this.contactUsername,
    this.lastMessagePreview,
    this.lastMessageAt,
    required this.unreadCount,
    required this.isOnline,
    required this.isPinned,
    required this.isMuted,
  });

  factory ConversationSummary.fromJson(Map<String, dynamic> json) =>
      ConversationSummary(
        id: json['id'] as String,
        type: json['type'] as String,
        contactUsername: json['contact_username'] as String?,
        lastMessagePreview: json['last_message_preview'] as String?,
        lastMessageAt: json['last_message_at'] != null
            ? DateTime.parse(json['last_message_at'] as String)
            : null,
        unreadCount: (json['unread_count'] as int?) ?? 0,
        isOnline: (json['is_online'] as bool?) ?? false,
        isPinned: (json['is_pinned'] as bool?) ?? false,
        isMuted: (json['is_muted'] as bool?) ?? false,
      );
}
