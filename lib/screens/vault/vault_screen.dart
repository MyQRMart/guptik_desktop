import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Required for Clipboard and ClipboardData
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/vault_file.dart';
import '../../services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  late final SupabaseService _supabaseService;
  late Future<List<VaultFile>> _filesFuture;
  final bool _isSyncing = false;
  String _vaultPath = '/home/user/Vault';
  final String _searchQuery = '';
  final String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _supabaseService = SupabaseService();
    _filesFuture = _getLocalVaultFiles();
    _loadVaultPath();
  }

  Future<List<VaultFile>> _getLocalVaultFiles() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vaultPath = prefs.getString('vault_path') ?? '/home/user/Vault';
      final directory = Directory(vaultPath);
      
      if (!directory.existsSync()) {
        return [];
      }
      
      final files = directory.listSync(recursive: true).whereType<File>().toList();
      final userId = _supabaseService.currentUserId ?? 'unknown';
      
      return files.map((file) {
        final stat = file.statSync();
        return VaultFile(
          userId: userId, // Fixed: Passes the required userId
          fileName: file.path.split('/').last,
          filePath: file.path,
          fileType: file.path.split('.').last,
          mimeType: _getMimeType(file.path),
          sizeBytes: BigInt.from(stat.size),
          isFavorite: false,
          syncedAt: stat.modified,
          createdAt: stat.changed,
          );
        }).toList();
    } catch (e) {
      throw Exception('Error reading vault files: $e');
    }
  }

  String _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      case 'mp4':
        return 'video/mp4';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _loadVaultPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vaultPath = prefs.getString('vault_path') ?? '/home/user/Vault';
    });
  }

  Future<void> _toggleFavorite(VaultFile file) async {
    final newState = !file.isFavorite;
    try {
      // Fixed: Uses the public client getter from the service
      await _supabaseService.client
          .from('vault_files')
          .update({'is_favorite': newState})
          .eq('id', file.id);

      setState(() {
        file.isFavorite = newState; // Requires removing 'final' from VaultFile model
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _handleShare(VaultFile file) async {
    final TextEditingController passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Share File"),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: "Password (Optional)"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final shareToken = DateTime.now().millisecondsSinceEpoch.toString();
              // Replace with your actual Cloudflare public URL logic
              final link = "https://share.myqrmart.com/vault/$shareToken";
              
              await Clipboard.setData(ClipboardData(text: link));
              if (mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Sharable link copied!")),
              );
            },
            child: const Text("Copy Link"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar( // Fixed: Corrected from app_bar to appBar
        title: const Text('Guptik Vault'),
        backgroundColor: const Color(0xFF1E293B),
        actions: [
          IconButton(
            icon: Icon(_isSyncing ? Icons.sync : Icons.refresh),
            onPressed: () => setState(() => _filesFuture = _getLocalVaultFiles()),
          ),
        ],
      ),
      body: FutureBuilder<List<VaultFile>>(
        future: _filesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final files = snapshot.data ?? [];
          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              childAspectRatio: 0.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: files.length,
            itemBuilder: (context, index) => _buildFileCard(files[index]),
          );
        },
      ),
    );
  }

  Widget _buildFileCard(VaultFile file) {
    final isImage = _isImage(file.fileName);
    final isVideo = _isVideo(file.fileName);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Stack(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: isImage
                    ? Image.file(File(file.filePath), fit: BoxFit.cover)
                    : Icon(
                        isVideo ? LucideIcons.video : LucideIcons.file,
                        size: 48,
                        color: Colors.blueGrey,
                      ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  file.fileName,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(LucideIcons.share2, size: 16),
                  onPressed: () => _handleShare(file),
                ),
                IconButton(
                  icon: Icon(
                    file.isFavorite ? LucideIcons.heart : LucideIcons.heartHandshake,
                    size: 16,
                    color: file.isFavorite ? Colors.red : Colors.grey,
                  ),
                  onPressed: () => _toggleFavorite(file),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isImage(String name) => name.toLowerCase().contains(RegExp(r'\.(jpg|jpeg|png|webp|gif)'));
  bool _isVideo(String name) => name.toLowerCase().contains(RegExp(r'\.(mp4|mov|ogg|wav)'));
}