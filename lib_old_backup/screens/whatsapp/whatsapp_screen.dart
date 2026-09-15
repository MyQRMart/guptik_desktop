import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/whatsapp/wa_conversation.dart';
import '../../services/whatsapp/wa_conversation_service.dart';
import 'whatsapp_chat_screen.dart';

class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  late final ConversationService _conversationService;
  late Future<List<Conversation>> _conversationsFuture;
  String _searchQuery = '';
  Conversation? _selectedConversation;

  @override
  void initState() {
    super.initState();
    _conversationService = ConversationService();
    _refreshConversations();
  }

  void _refreshConversations() {
    setState(() {
      // Fetches all conversations (individual + group) sorted by time
      _conversationsFuture = _conversationService.getConversations();
    });
  }

  void _selectConversation(Conversation conversation) async {
    setState(() {
      _selectedConversation = conversation;
    });
    
    // Mark as read immediately upon selection
    if (conversation.isUnread) {
      await _conversationService.markAsRead(conversation.id);
      _refreshConversations(); // Refresh UI to remove unread dot
    }
  }

  void _goBack() {
    setState(() {
      _selectedConversation = null;
    });
    _refreshConversations(); // Refresh list when returning
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedConversation != null) {
      return WhatsAppChatScreen(
        conversation: _selectedConversation!,
        onBack: _goBack,
      );
    }

    return Row(
      children: [
        // CONVERSATIONS LIST SIDEBAR
        Container(
          width: 350,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'WhatsApp',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          onPressed: _refreshConversations,
                          icon: const Icon(LucideIcons.refreshCw, size: 20, color: Colors.grey),
                          tooltip: 'Refresh',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Search Bar
                    TextField(
                      onChanged: (value) => setState(() => _searchQuery = value.toLowerCase()),
                      decoration: InputDecoration(
                        hintText: 'Search chats...',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        prefixIcon: const Icon(LucideIcons.search, color: Colors.grey, size: 20),
                        filled: true,
                        fillColor: Colors.black.withOpacity(0.2),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              // Conversations List
              Expanded(
                child: FutureBuilder<List<Conversation>>(
                  future: _conversationsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                    }

                    final conversations = snapshot.data ?? [];
                    final filtered = conversations.where((c) {
                      final name = c.contactName?.toLowerCase() ?? '';
                      final phone = c.phoneNumber.toLowerCase();
                      return name.contains(_searchQuery) || phone.contains(_searchQuery);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Text(
                          _searchQuery.isEmpty ? 'No conversations found' : 'No matches',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (c, i) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                      itemBuilder: (context, index) => _buildConversationTile(filtered[index]),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // EMPTY STATE (Right Side)
        Expanded(
          child: Container(
            color: const Color(0xFF0F172A),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.messageSquare, size: 80, color: Colors.grey.shade800),
                const SizedBox(height: 24),
                Text(
                  'Select a conversation',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _selectConversation(conversation),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: conversation.isGroup ? Colors.orange.withOpacity(0.2) : Colors.cyanAccent.withOpacity(0.2),
                child: Text(
                  conversation.initials,
                  style: TextStyle(
                    color: conversation.isGroup ? Colors.orangeAccent : Colors.cyanAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            conversation.displayName,
                            style: TextStyle(
                              fontWeight: conversation.isUnread ? FontWeight.bold : FontWeight.w500,
                              color: Colors.white,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          _formatDate(conversation.timestamp),
                          style: TextStyle(
                            color: conversation.isUnread ? Colors.greenAccent : Colors.grey.shade600,
                            fontSize: 11,
                            fontWeight: conversation.isUnread ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (conversation.isGroup) ...[
                           Icon(LucideIcons.bot, size: 12, color: Colors.grey.shade500),
                           const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            conversation.lastMessage ?? 'No messages',
                            style: TextStyle(
                              color: conversation.isUnread ? Colors.white70 : Colors.grey.shade500,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (conversation.isUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (now.day == date.day && now.month == date.month && now.year == date.year) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}';
  }
}