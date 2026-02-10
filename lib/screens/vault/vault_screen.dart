import 'package:flutter/material.dart';
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
  bool _isSyncing = false;
  String _vaultPath = '/home/user/Vault';
  String _searchQuery = '';
  String _selectedFilter = 'all';

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
          userId: userId,
          fileName: file.path.split('/').last,
          filePath: file.path,
          fileType: file.path.split('.').last,
          mimeType: _getMimeType(file.path),
          sizeBytes: BigInt.from(stat.size),
          isFavorite: false,
          syncedAt: stat.modified ?? DateTime.now(),
          createdAt: stat.changed ?? DateTime.now(),
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
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _loadVaultPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _vaultPath = prefs.getString('vault_path') ?? '/home/user/Vault';
    });
    // Reload files after path load
    setState(() {
      _filesFuture = _getLocalVaultFiles();
    });
  }

  Future<void> _saveVaultPath(String newPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vault_path', newPath);
    setState(() {
      _vaultPath = newPath;
    });
  }

  Future<void> _syncFiles() async {
    setState(() => _isSyncing = true);
    try {
      // Simulate sync
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _filesFuture = _getLocalVaultFiles();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sync completed successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _showSettingsDialog() {
    final pathController = TextEditingController(text: _vaultPath);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          'Vault Settings',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vault Location',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pathController,
              decoration: InputDecoration(
                hintText: 'Enter vault path...',
                hintStyle: TextStyle(color: Colors.grey.shade600),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Current: $_vaultPath',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              _saveVaultPath(pathController.text).then((_) {
                Navigator.pop(context);
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VaultFile>>(
      future: _filesFuture,
      builder: (context, snapshot) {
        final files = snapshot.data ?? [];
        
        // Filter files based on search and filter type
        final filteredFiles = files.where((file) {
          final matchesSearch = file.fileName.toLowerCase().contains(_searchQuery.toLowerCase());
          
          if (_selectedFilter == 'all') return matchesSearch;
          if (_selectedFilter == 'images') {
            return matchesSearch && (file.mimeType?.startsWith('image/') ?? false);
          }
          if (_selectedFilter == 'documents') {
            return matchesSearch && (file.mimeType?.startsWith('application/') ?? false);
          }
          if (_selectedFilter == 'videos') {
            return matchesSearch && (file.mimeType?.startsWith('video/') ?? false);
          }
          if (_selectedFilter == 'favorites') {
            return matchesSearch && file.isFavorite;
          }
          return matchesSearch;
        }).toList();

        final totalSize = files.fold<BigInt>(
          BigInt.zero,
          (sum, file) => sum + (file.sizeBytes ?? BigInt.zero),
        );

        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with Sync and Settings
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'VAULT STORAGE',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _isSyncing ? null : _syncFiles,
                          icon: _isSyncing
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.black,
                                    ),
                                  ),
                                )
                              : const Icon(LucideIcons.refreshCw),
                          label: Text(_isSyncing ? 'SYNCING...' : 'SYNC NOW'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _showSettingsDialog,
                          icon: const Icon(LucideIcons.settings),
                          label: const Text('SETTINGS'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                // Storage Stats
                Row(
                  children: [
                    _buildStatCard('Total Files', '${files.length}'),
                    const SizedBox(width: 16),
                    _buildStatCard(
                      'Storage Used',
                      _formatBytes(totalSize),
                    ),
                    const SizedBox(width: 16),
                    _buildStatCard(
                      'Encrypted',
                      'YES',
                      color: Colors.greenAccent,
                    ),
                  ],
                ),
                const SizedBox(height: 30),

                // Filter and Search
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                        decoration: InputDecoration(
                          hintText: 'Search files...',
                          hintStyle: TextStyle(color: Colors.grey.shade600),
                          prefixIcon: const Icon(LucideIcons.search, color: Colors.grey),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 16),
                    _buildFilterButton('All', 'all'),
                    const SizedBox(width: 8),
                    _buildFilterButton('Images', 'images'),
                    const SizedBox(width: 8),
                    _buildFilterButton('Documents', 'documents'),
                    const SizedBox(width: 8),
                    _buildFilterButton('Videos', 'videos'),
                    const SizedBox(width: 8),
                    _buildFilterButton('Favorites', 'favorites'),
                  ],
                ),
                const SizedBox(height: 24),

                // File Grid
                if (snapshot.connectionState == ConnectionState.waiting)
                  const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  )
                else if (snapshot.hasError)
                  Center(
                    child: Text(
                      'Error loading files',
                      style: TextStyle(color: Colors.red.shade400),
                    ),
                  )
                else if (filteredFiles.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          LucideIcons.inbox,
                          size: 64,
                          color: Colors.grey.shade700,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No files' : 'No matching files',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      childAspectRatio: 0.9,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: filteredFiles.length,
                    itemBuilder: (context, index) {
                      final file = filteredFiles[index];
                      return _buildFileCard(file);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterButton(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ElevatedButton(
      onPressed: () => setState(() => _selectedFilter = value),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.cyanAccent : Colors.grey.shade800,
        foregroundColor: isSelected ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildStatCard(String title, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard(VaultFile file) {
    final isImage = file.mimeType?.startsWith('image/') ?? false;
    
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
              Icon(
                isImage ? LucideIcons.image : _getFileIcon(file.fileType),
                size: 48,
                color: Colors.blueGrey,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  file.fileName,
                  style: const TextStyle(fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                file.fileSizeFormatted,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          // Favorite button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () async {
                await _supabaseService.updateVaultFileFavorite(
                  file.id,
                  !file.isFavorite,
                );
                setState(() {
                  _filesFuture = _supabaseService.getVaultFiles();
                });
              },
              icon: Icon(
                file.isFavorite ? LucideIcons.heart : LucideIcons.heartHandshake,
                size: 16,
                color: file.isFavorite ? Colors.red.shade400 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon(String? fileType) {
    if (fileType == null) return LucideIcons.file;
    
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return LucideIcons.fileText;
      case 'doc':
      case 'docx':
        return LucideIcons.fileText;
      case 'xls':
      case 'xlsx':
        return LucideIcons.table;
      case 'zip':
      case 'rar':
        return LucideIcons.package;
      case 'mp4':
      case 'avi':
        return LucideIcons.video;
      case 'mp3':
      case 'wav':
        return LucideIcons.music;
      default:
        return LucideIcons.file;
    }
  }

  String _formatBytes(BigInt bytes) {
    if (bytes == BigInt.zero) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var b = bytes.toDouble();
    var i = 0;
    
    while (b > 1024 && i < suffixes.length - 1) {
      b /= 1024;
      i++;
    }
    
    return '${b.toStringAsFixed(2)} ${suffixes[i]}';
  }
}