import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/conversation.dart';
import '../../models/message.dart';
import '../../services/supabase_service.dart';

class WhatsAppChatScreen extends StatefulWidget {
  final Conversation conversation;
  final VoidCallback onBack;

  const WhatsAppChatScreen({
    required this.conversation,
    required this.onBack,
    super.key,
  });

  @override
  State<WhatsAppChatScreen> createState() => _WhatsAppChatScreenState();
}

class _WhatsAppChatScreenState extends State<WhatsAppChatScreen> {
  late final SupabaseService _supabaseService;
  late Future<List<Message>> _messagesFuture;
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _supabaseService = SupabaseService();
    _messagesFuture = _supabaseService.getMessages(widget.conversation.id);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      final message = Message(
        conversationId: widget.conversation.id,
        messageId: DateTime.now().millisecondsSinceEpoch.toString(),
        content: text,
        messageType: 'text',
        direction: 'outgoing',
        status: 'pending',
        timestamp: DateTime.now().toIso8601String(),
      );

      await _supabaseService.createMessage(message);
      _messageController.clear();

      // Refresh messages
      setState(() {
        _messagesFuture = _supabaseService.getMessages(widget.conversation.id);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending message: ${e.toString()}'),
          backgroundColor: Colors.red.shade400,
        ),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
                tooltip: 'Back',
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.conversation.contactName ?? widget.conversation.phoneNumber,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      widget.conversation.phoneNumber,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(LucideIcons.phone, color: Colors.cyanAccent),
                tooltip: 'Call',
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(LucideIcons.moreVertical, color: Colors.white),
                tooltip: 'Options',
              ),
            ],
          ),
        ),
        // Messages Area
        Expanded(
          child: FutureBuilder<List<Message>>(
            future: _messagesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.cyanAccent),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading messages',
                    style: TextStyle(color: Colors.red.shade400),
                  ),
                );
              }

              final messages = snapshot.data ?? [];

              if (messages.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.messageCircle,
                        size: 64,
                        color: Colors.grey.shade700,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No messages yet',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return _buildMessageBubble(message);
                },
              );
            },
          ),
        ),
        // Input Area
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: () {},
                icon: const Icon(LucideIcons.paperclip, color: Colors.cyanAccent),
                tooltip: 'Attach file',
              ),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.grey.shade600),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Colors.cyanAccent),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.cyanAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(LucideIcons.send, color: Colors.cyanAccent),
                tooltip: 'Send',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isOutgoing = message.isOutgoing;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Align(
        alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isOutgoing ? Colors.cyanAccent : const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: isOutgoing
                ? null
                : Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.4,
          ),
          child: Column(
            crossAxisAlignment:
                isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Text(
                message.content,
                style: TextStyle(
                  color: isOutgoing ? Colors.black : Colors.white,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      color:
                          isOutgoing ? Colors.black54 : Colors.grey.shade500,
                      fontSize: 11,
                    ),
                  ),
                  if (isOutgoing) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.status == 'read'
                          ? LucideIcons.check
                          : LucideIcons.check,
                      size: 12,
                      color: Colors.black54,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '';
    }
  }
}
