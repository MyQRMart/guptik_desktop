import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Needed for self-healing
import '../../models/vault_file.dart';
import '../../services/supabase_service.dart';
import '../../services/storage_service.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final StorageService _storage = StorageService();
  final SupabaseService _supabase = SupabaseService();
  
  List<VaultFile> _files = [];
  bool _isLoading = true;
  String? _vaultPath; // This will now point to .../vault_files
  String? _publicUrl;

  @override
  void initState() {
    super.initState();
    _loadConfigAndFiles();
  }

  Future<void> _loadConfigAndFiles() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    String? storedPath = prefs.getString('vault_path');
    String? storedUrl = await _storage.getPublicUrl();
    String? deviceId = await _storage.getDeviceId();

    // SELF-HEALING: If path is missing locally, fetch from Database
    if (storedPath == null && deviceId != null) {
      try {
        final data = await Supabase.instance.client
            .from('desktop_devices')
            .select('vault_path')
            .eq('device_id', deviceId)
            .maybeSingle();
            
        if (data != null && data['vault_path'] != null) {
          storedPath = data['vault_path'];
          await prefs.setString('vault_path', storedPath!); // Save for next time
        }
      } catch (e) {
        print("Error fetching path from DB: $e");
      }
    }

    // Fallback (Only if DB fetch also failed)
    if (storedPath == null) {
       if (Platform.isWindows) storedPath = 'C:\\GuptikVault';
       else storedPath = '${Platform.environment['HOME']}/GuptikVault';
    }

    // CRITICAL FIX: Append 'vault_files' to the path
    // The Docker container maps this specific subfolder to /app/storage
    final String correctVaultPath = "$storedPath${Platform.pathSeparator}vault_files";

    if (mounted) {
      setState(() {
        _vaultPath = correctVaultPath;
        _publicUrl = storedUrl;
      });
      await _refreshFiles();
    }
  }

  Future<void> _refreshFiles() async {
    if (_vaultPath == null) return;

    final dir = Directory(_vaultPath!);
    
    // Auto-create if missing (e.g. first run)
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    try {
      final List<FileSystemEntity> entities = dir.listSync(recursive: false); // recursive: false is safer for flat vaults
      final List<File> files = entities.whereType<File>().toList();
      
      files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      final userId = _supabase.currentUserId ?? 'local-user';

      List<VaultFile> loadedFiles = files.map((file) {
        final stat = file.statSync();
        return VaultFile(
          id: file.path.hashCode.toString(),
          userId: userId,
          fileName: file.path.split(Platform.pathSeparator).last,
          filePath: file.path,
          fileType: file.path.split('.').last,
          mimeType: _getMimeType(file.path),
          sizeBytes: BigInt.from(stat.size),
          isFavorite: false,
          syncedAt: stat.modified,
          createdAt: stat.changed,
        );
      }).toList();

      if (mounted) {
        setState(() {
          _files = loadedFiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error reading vault: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleShare(VaultFile file) {
    if (_publicUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Public URL not configured. Check Settings.")),
      );
      return;
    }

    final safeName = file.fileName ?? "file";
    final String shareLink = "https://$_publicUrl/vault/files/${Uri.encodeComponent(safeName)}";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Share File", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Public Link:", style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            const SizedBox(height: 10),
            SelectableText(
              shareLink,
              style: const TextStyle(color: Colors.cyanAccent, fontFamily: 'Courier', fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close")),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, size: 16),
            label: const Text("Copy"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: shareLink));
              if (mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Link copied!")),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openFile(String? path) async {
    if (path == null) return;
    try {
      if (Platform.isLinux) await Process.run('xdg-open', [path]);
      else if (Platform.isMacOS) await Process.run('open', [path]);
      else if (Platform.isWindows) await Process.run('explorer', [path]);
    } catch (e) {
      print("Could not open file: $e");
    }
  }

  String _getMimeType(String? path) {
    if (path == null) return 'application/octet-stream';
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png': return 'image/png';
      case 'pdf': return 'application/pdf';
      case 'mp4': return 'video/mp4';
      default: return 'application/octet-stream';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Local Vault"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
           IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: "Open in File Manager",
            onPressed: () { if (_vaultPath != null) _openFile(_vaultPath); },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshFiles,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _files.isEmpty 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Vault is Empty", style: TextStyle(color: Colors.grey, fontSize: 18)),
                    const SizedBox(height: 10),
                    Text("Folder: $_vaultPath", style: TextStyle(color: Colors.grey[700], fontFamily: 'Courier')),
                  ],
                )
              )
            : GridView.builder(
                padding: const EdgeInsets.all(24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _files.length,
                itemBuilder: (context, index) => _buildFileCard(_files[index]),
              ),
    );
  }

  Widget _buildFileCard(VaultFile file) {
    final fType = (file.fileType ?? "").toLowerCase();
    final bool isImg = ['jpg','jpeg','png','webp'].contains(fType);
    final safePath = file.filePath ?? "";

    return InkWell(
      onTap: () => _openFile(safePath),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Expanded(
              child: isImg && safePath.isNotEmpty
                  ? Image.file(File(safePath), fit: BoxFit.cover)
                  : Icon(_getFileIcon(fType), size: 40, color: Colors.cyanAccent),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.fileName ?? "Unknown", 
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatSize(file.sizeBytes),
                    style: TextStyle(color: Colors.grey[500], fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String ext) {
    switch (ext) {
      case 'pdf': return LucideIcons.fileText;
      case 'mp4': return LucideIcons.video;
      case 'zip': return LucideIcons.archive;
      default: return LucideIcons.file;
    }
  }

  String _formatSize(BigInt? bytes) {
    if (bytes == null) return '0 B';
    int b = bytes.toInt();
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}