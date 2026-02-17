import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/whatsapp/wa_conversation.dart';
import '../../models/whatsapp/wa_message.dart';
import '../../services/whatsapp/wa_message_service.dart';

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
  late final MessageService _messageService;
  late Stream<List<Message>> _messagesStream;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messageService = MessageService();
    // Use the stream subscription provided by the service for real-time updates
    _messagesStream = _messageService.subscribeToMessages(widget.conversation.id);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);

    try {
      // Use the actual service that hits the WhatsApp API
      await _messageService.sendTextMessage(
        conversationId: widget.conversation.id,
        content: text,
        toPhoneNumber: widget.conversation.phoneNumber,
        isAI: false, // Desktop user sending manually
      );
      
      _messageController.clear();
      _scrollToBottom();
      
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red.shade400,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Chat Header
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
              ),
              const SizedBox(width: 16),
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                child: Text(
                  widget.conversation.initials,
                  style: const TextStyle(color: Colors.cyanAccent, fontSize: 14),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.conversation.displayName,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      widget.conversation.phoneNumber,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Messages List
        Expanded(
          child: StreamBuilder<List<Message>>(
            stream: _messagesStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
              }

              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return Center(
                  child: Text('No messages yet', style: TextStyle(color: Colors.grey.shade600)),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
              Expanded(
                child: TextField(
                  controller: _messageController,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.2),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _isSending ? null : _sendMessage,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(12),
                ),
                icon: _isSending 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(LucideIcons.send, color: Colors.black, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Message message) {
    final isMe = message.isOutgoing;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF00A884) : const Color(0xFF334155),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(isMe ? 12 : 0),
            bottomRight: Radius.circular(isMe ? 0 : 12),
          ),
        ),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.hasMedia)
               const Padding(
                 padding: EdgeInsets.only(bottom: 8.0),
                 child: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     Icon(LucideIcons.image, size: 16, color: Colors.white70),
                     SizedBox(width: 4),
                     Text("[Media Message]", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.white70)),
                   ],
                 ),
               ),
            Text(
              message.content,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.formattedTime,
                  style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? LucideIcons.checkCheck : LucideIcons.check,
                    size: 12,
                    color: message.isRead ? Colors.cyanAccent : Colors.white60,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}