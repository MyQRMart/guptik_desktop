import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/conversation.dart';
import '../../services/supabase_service.dart';
import 'whatsapp_chat_screen.dart';

class WhatsAppScreen extends StatefulWidget {
  const WhatsAppScreen({super.key});

  @override
  State<WhatsAppScreen> createState() => _WhatsAppScreenState();
}

class _WhatsAppScreenState extends State<WhatsAppScreen> {
  late final SupabaseService _supabaseService;
  late Future<List<Conversation>> _conversationsFuture;
  String _searchQuery = '';
  Conversation? _selectedConversation;

  @override
  void initState() {
    super.initState();
    _supabaseService = SupabaseService();
    _conversationsFuture = _supabaseService.getConversations();
  }

  void _selectConversation(Conversation conversation) {
    setState(() {
      _selectedConversation = conversation;
    });
  }

  void _goBack() {
    setState(() {
      _selectedConversation = null;
    });
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
        // CONVERSATIONS LIST
        Container(
          width: 320,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'WhatsApp',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Search Bar
                    TextField(
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                      },
                      decoration: InputDecoration(
                        hintText: 'Search conversations...',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        prefixIcon: const Icon(LucideIcons.search, color: Colors.grey),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  ],
                ),
              ),
              // Conversations List
              Expanded(
                child: FutureBuilder<List<Conversation>>(
                  future: _conversationsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.cyanAccent),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading conversations',
                          style: TextStyle(color: Colors.red.shade400),
                        ),
                      );
                    }

                    final conversations = snapshot.data ?? [];
                    final filtered = conversations
                        .where((c) =>
                            (c.contactName?.toLowerCase().contains(_searchQuery) ?? false) ||
                            c.phoneNumber.contains(_searchQuery))
                        .toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              LucideIcons.messageCircle,
                              size: 48,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty ? 'No conversations' : 'No matches found',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final conversation = filtered[index];
                        return _buildConversationTile(conversation);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // EMPTY STATE OR CHAT AREA
        Expanded(
          child: Container(
            color: const Color(0xFF0F172A),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.messageCircle,
                    size: 80,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Select a conversation to start',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
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
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.05))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    conversation.contactName ?? conversation.phoneNumber,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (conversation.isUnread)
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                conversation.lastMessage ?? 'No messages',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                  fontStyle: conversation.lastMessage == null ? FontStyle.italic : FontStyle.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                conversation.lastMessageTime,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
