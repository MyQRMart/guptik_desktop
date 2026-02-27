import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/facebook/meta_service.dart';
import '../../models/facebook/meta_chat_model.dart';
import '../../models/facebook/meta_content_model.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';

class MetaDashboard extends StatefulWidget {
  const MetaDashboard({super.key});

  @override
  State<MetaDashboard> createState() => _MetaDashboardState();
}

class _MetaDashboardState extends State<MetaDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: const Color(0xFF1E293B),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.cyanAccent,
            labelColor: Colors.cyanAccent,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(icon: Icon(LucideIcons.grid), text: "Content"),
              Tab(icon: Icon(LucideIcons.messageCircle), text: "Inbox"),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Desktop friendly
        children: const [
          _ContentTab(),
          _InboxTab(),
        ],
      ),
    );
  }
}

// ================= CONTENT TAB =================
class _ContentTab extends StatefulWidget {
  const _ContentTab();
  @override
  State<_ContentTab> createState() => _ContentTabState();
}

class _ContentTabState extends State<_ContentTab> {
  final MetaService _meta = MetaService();
  SocialPlatform _platform = SocialPlatform.facebook;
  ContentType _filter = ContentType.post;

  void _showCreateDialog() {
    showDialog(context: context, builder: (ctx) => _CreatePostDialog(platform: _platform));
  }

  void _openMedia(MetaContent post) {
    if (post.videoUrl != null && post.videoUrl!.isNotEmpty) {
      showDialog(context: context, builder: (ctx) => _VideoPlayerDialog(videoUrl: post.videoUrl!));
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.transparent,
          content: Image.network(post.imageUrl, fit: BoxFit.contain),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              DropdownButton<SocialPlatform>(
                value: _platform,
                dropdownColor: const Color(0xFF1E293B),
                style: const TextStyle(color: Colors.white),
                items: SocialPlatform.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()))).toList(),
                onChanged: (val) => setState(() => _platform = val!),
              ),
              const SizedBox(width: 20),
              ...ContentType.values.map((t) => Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(t.name.toUpperCase()),
                  selected: _filter == t,
                  onSelected: (val) => setState(() => _filter = t),
                  selectedColor: Colors.cyanAccent.withOpacity(0.2),
                  backgroundColor: const Color(0xFF1E293B),
                  labelStyle: TextStyle(color: _filter == t ? Colors.cyanAccent : Colors.grey),
                ),
              )),
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.add),
                label: const Text("Create"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                onPressed: _showCreateDialog,
              )
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<MetaContent>>(
            future: _meta.getContent(_platform, _filter),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
              if (snap.data?.isEmpty ?? true) return const Center(child: Text("No content", style: TextStyle(color: Colors.grey)));
              
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 16, mainAxisSpacing: 16),
                itemCount: snap.data!.length,
                itemBuilder: (ctx, i) {
                  final post = snap.data![i];
                  return GestureDetector(
                    onTap: () => _openMedia(post),
                    child: Container(
                      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12)),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: post.imageUrl.isNotEmpty 
                                ? Image.network(post.imageUrl, fit: BoxFit.cover) 
                                : const Icon(Icons.image, color: Colors.grey, size: 50),
                          ),
                          if (post.videoUrl != null)
                            const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 50)),
                          Positioned(
                            bottom: 0, left: 0, right: 0,
                            child: Container(
                              color: Colors.black.withOpacity(0.7),
                              padding: const EdgeInsets.all(8.0),
                              child: Text(post.caption, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ================= CREATE POST DIALOG =================
class _CreatePostDialog extends StatefulWidget {
  final SocialPlatform platform;
  const _CreatePostDialog({required this.platform});
  @override
  State<_CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<_CreatePostDialog> {
  final MetaService _meta = MetaService();
  final TextEditingController _ctrl = TextEditingController();
  File? _file;
  bool _isVideo = false;
  bool _isUploading = false;

  void _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
    if (result != null) {
      setState(() {
        _file = File(result.files.single.path!);
        _isVideo = result.files.single.extension?.toLowerCase() == 'mp4';
      });
    }
  }

  void _post() async {
    if (_file == null) return;
    setState(() => _isUploading = true);
    final success = await _meta.uploadPost(widget.platform, _file!, _ctrl.text, _isVideo);
    setState(() => _isUploading = false);
    if (mounted) Navigator.pop(context, success);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text("New ${widget.platform.name} Post", style: const TextStyle(color: Colors.white)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _pickMedia,
              child: Container(
                height: 150, width: double.infinity,
                decoration: BoxDecoration(border: Border.all(color: Colors.cyanAccent), borderRadius: BorderRadius.circular(8)),
                child: _file == null 
                  ? const Center(child: Text("Click to select Image/Video", style: TextStyle(color: Colors.cyanAccent)))
                  : Center(child: Icon(_isVideo ? Icons.videocam : Icons.image, color: Colors.cyanAccent, size: 50)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(hintText: "Caption...", hintStyle: TextStyle(color: Colors.grey), filled: true, fillColor: Color(0xFF0F172A)),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        _isUploading 
          ? const CircularProgressIndicator(color: Colors.cyanAccent)
          : ElevatedButton(onPressed: _post, style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black), child: const Text("Post")),
      ],
    );
  }
}

// ================= VIDEO PLAYER DIALOG =================
class _VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  const _VideoPlayerDialog({required this.videoUrl});
  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
        _controller.setLooping(true);
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_controller.value.isInitialized)
            AspectRatio(
              aspectRatio: _controller.value.aspectRatio,
              child: VideoPlayer(_controller),
            )
          else
            const CircularProgressIndicator(color: Colors.cyanAccent),
          Positioned(
            top: 10, right: 10,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          )
        ],
      ),
    );
  }
}

// ================= INBOX SPLIT TAB =================
class _InboxTab extends StatefulWidget {
  const _InboxTab();
  @override
  State<_InboxTab> createState() => _InboxTabState();
}

class _InboxTabState extends State<_InboxTab> {
  final MetaService _meta = MetaService();
  MetaChat? _selectedChat;
  List<MetaChat> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  void _loadChats() async {
    final chats = await _meta.getUnifiedInbox();
    setState(() => _chats = chats);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Left: Chat List
        Container(
          width: 300,
          decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1)))),
          child: ListView.builder(
            itemCount: _chats.length,
            itemBuilder: (ctx, i) {
              final chat = _chats[i];
              final isSelected = _selectedChat?.id == chat.id;
              return ListTile(
                tileColor: isSelected ? Colors.white.withOpacity(0.05) : null,
                leading: CircleAvatar(backgroundColor: Colors.grey[800], child: Text(chat.senderName[0], style: const TextStyle(color: Colors.cyanAccent))),
                title: Text(chat.senderName, style: const TextStyle(color: Colors.white)),
                subtitle: Text(chat.lastMessage, maxLines: 1, style: const TextStyle(color: Colors.grey)),
                trailing: chat.platform == SocialPlatform.facebook ? const Icon(LucideIcons.facebook, size: 14, color: Colors.blue) : const Icon(LucideIcons.instagram, size: 14, color: Colors.pink),
                onTap: () => setState(() => _selectedChat = chat),
              );
            },
          ),
        ),
        // Right: Chat Detail
        Expanded(
          child: _selectedChat == null
              ? const Center(child: Text("Select a chat", style: TextStyle(color: Colors.grey)))
              : _ChatDetailView(chat: _selectedChat!),
        )
      ],
    );
  }
}

// ================= CHAT DETAIL VIEW =================
class _ChatDetailView extends StatefulWidget {
  final MetaChat chat;
  const _ChatDetailView({required this.chat});
  @override
  State<_ChatDetailView> createState() => _ChatDetailViewState();
}

class _ChatDetailViewState extends State<_ChatDetailView> {
  final MetaService _meta = MetaService();
  final TextEditingController _ctrl = TextEditingController();
  List<Map<String, dynamic>> _msgs = [];

  @override
  void didUpdateWidget(covariant _ChatDetailView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chat.id != widget.chat.id) _loadMsgs();
  }

  @override
  void initState() {
    super.initState();
    _loadMsgs();
  }

  void _loadMsgs() async {
    final msgs = await _meta.getChatMessages(widget.chat.id);
    setState(() => _msgs = msgs);
  }

  void _send() async {
    if (_ctrl.text.isEmpty) return;
    final text = _ctrl.text;
    _ctrl.clear();
    setState(() => _msgs.insert(0, {'message': text, 'is_from_me': true, 'created_time': DateTime.now().toIso8601String()}));
    await _meta.sendMessage(widget.chat.id, text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFF1E293B),
          child: Row(children: [Text(widget.chat.senderName, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))]),
        ),
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(16),
            itemCount: _msgs.length,
            itemBuilder: (ctx, i) {
              final msg = _msgs[i];
              final isMe = msg['is_from_me'] ?? false;
              return Align(
                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isMe ? Colors.cyan.withOpacity(0.2) : const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isMe ? Colors.cyanAccent : Colors.transparent),
                  ),
                  child: Text(msg['message'], style: const TextStyle(color: Colors.white)),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Type...", hintStyle: const TextStyle(color: Colors.grey),
                    filled: true, fillColor: const Color(0xFF1E293B),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(icon: const Icon(Icons.send, color: Colors.cyanAccent), onPressed: _send),
            ],
          ),
        )
      ],
    );
  }
}