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

  Future<void> _pickPath() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() => _vaultPath = selectedDirectory);
    }
  }

  Future<void> _confirmSelection() async {
    if (_vaultPath == null) return;

    await Supabase.instance.client
        .from('desktop_devices')
        .update({
          'vault_path': _vaultPath,
          'installation_status': 'provisioning'
        })
        .eq('device_id', widget.deviceId);

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => InstallationScreen(deviceId: widget.deviceId, vaultPath: _vaultPath!))
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
            const Text("SELECT VAULT LOCATION", style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            const Text("Choose a local folder for your Docker volumes and data.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 50),
            GestureDetector(
              onTap: _pickPath,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _vaultPath != null ? Colors.cyanAccent : Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder, size: 40, color: Colors.cyanAccent),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Text(_vaultPath ?? "Select Folder...", style: TextStyle(color: _vaultPath != null ? Colors.white : Colors.grey)),
                    ),
                    const Icon(Icons.search, color: Colors.white),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _vaultPath != null ? _confirmSelection : null,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
                child: const Text("PROCEED TO INSTALLATION", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }
}