import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'installation_screen.dart';

class StorageSelectionScreen extends StatefulWidget {
  final String deviceId;
  const StorageSelectionScreen({super.key, required this.deviceId});

  @override
  State<StorageSelectionScreen> createState() => _StorageSelectionScreenState();
}

class _StorageSelectionScreenState extends State<StorageSelectionScreen> {
  String? _vaultPath;
  String? _systemPath;

  Future<void> _pickPath(bool isVault) async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        if (isVault) {
          _vaultPath = selectedDirectory;
        } else {
          _systemPath = selectedDirectory;
        }
      });
    }
  }

  Future<void> _confirmSelection() async {
    if (_vaultPath == null || _systemPath == null) return;

    // Save paths to Supabase so we know where this device stores data
    await Supabase.instance.client
        .from('desktop_devices')
        .update({
          'vault_path': _vaultPath,
          'services_path': _systemPath,
          'installation_status': 'installing' // Move to next step
        })
        .eq('device_id', widget.deviceId);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => InstallationScreen(
            deviceId: widget.deviceId, 
            systemPath: _systemPath!
          )
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("CONFIGURE STORAGE", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            const Text("Select where your data will live on this machine.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 50),

            _buildPathSelector("Vault Location", "Where photos, videos, and documents will be stored.", _vaultPath, true),
            const SizedBox(height: 30),
            _buildPathSelector("System Data", "Where AI models (Ollama) and Databases (Supabase) will live.", _systemPath, false),

            const Spacer(),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: (_vaultPath != null && _systemPath != null) ? _confirmSelection : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text("START INSTALLATION"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPathSelector(String title, String subtitle, String? path, bool isVault) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(isVault ? Icons.folder_shared : Icons.settings_system_daydream, size: 40, color: Colors.blueGrey),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (path != null) ...[
                  const SizedBox(height: 8),
                  Text(path, style: const TextStyle(color: Colors.cyanAccent, fontFamily: 'Courier', fontSize: 12)),
                ]
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _pickPath(isVault),
            child: const Text("BROWSE"),
          )
        ],
      ),
    );
  }
}