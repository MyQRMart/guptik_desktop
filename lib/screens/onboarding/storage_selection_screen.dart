import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/external/docker_service.dart';
import 'installation_screen.dart';

class StorageSelectionScreen extends StatefulWidget {
  final String deviceId;
  final String userEmail;
  final String userPassword;
  final String cfToken;
  final String publicUrl;

  const StorageSelectionScreen({
    super.key,
    required this.deviceId,
    required this.userEmail,
    required this.userPassword,
    required this.cfToken,
    required this.publicUrl,
  });

  @override
  State<StorageSelectionScreen> createState() => _StorageSelectionScreenState();
}

class _StorageSelectionScreenState extends State<StorageSelectionScreen> {
  String? _selectedPath;
  GuptikStack? _existing;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  Future<void> _detect() async {
    final existing = await DockerService.findExistingStack();
    if (!mounted) return;
    setState(() {
      _existing = existing;
      if (existing != null) _selectedPath = existing.workingDir;
      _checking = false;
    });
  }

  Future<void> _pickPath() async {
    final result = await FilePicker.platform.getDirectoryPath();
    if (result != null) setState(() => _selectedPath = result);
  }

  void _continue({bool reuse = false}) {
    final path = reuse ? _existing?.workingDir : _selectedPath;
    if (path == null) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InstallationScreen(
          deviceId: widget.deviceId,
          vaultPath: path,
          userEmail: widget.userEmail,
          userPassword: widget.userPassword,
          cfToken: widget.cfToken,
          publicUrl: widget.publicUrl,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: _checking
              ? const CircularProgressIndicator(color: Color(0xFF00E5FF))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('GupTik node',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    if (_existing != null) ...[
                      Text(
                        _existing!.running
                            ? 'A GupTik stack is already running on this PC.'
                            : 'A GupTik stack already exists on this PC.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Text(_existing!.workingDir,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white54, fontFamily: 'Courier', fontSize: 12)),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () => _continue(reuse: true),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
                        child: const Text('USE EXISTING NODE', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 28),
                      const Text('or pick a new folder (only if you really want a fresh node)',
                          style: TextStyle(color: Colors.white38, fontSize: 11)),
                      const SizedBox(height: 12),
                    ] else
                      const Text('Pick a folder. GupTik will create a GupTik/ folder inside it.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    if (_selectedPath != null && _existing == null)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Node: ${DockerService.nestNodeDir(_selectedPath!)}',
                          style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier', fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _pickPath,
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('SELECT FOLDER'),
                    ),
                    const SizedBox(height: 16),
                    if (_existing == null)
                      ElevatedButton(
                        onPressed: _selectedPath != null ? _continue : null,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF)),
                        child: const Text('START INSTALLATION', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
