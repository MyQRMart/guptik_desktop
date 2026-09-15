import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
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

  Future<void> _pickPath() async {
    String? result = await FilePicker.platform.getDirectoryPath();
    if (result != null) {
      setState(() => _selectedPath = result);
    }
  }

  void _continue() {
    if (_selectedPath == null) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InstallationScreen(
          deviceId: widget.deviceId,
          vaultPath: _selectedPath!,
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
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("WHERE SHOULD WE STORE YOUR DATA?", 
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 30),
            
            if (_selectedPath != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(_selectedPath!, style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier')),
              ),
            
            const SizedBox(height: 20),
            
            ElevatedButton.icon(
              onPressed: _pickPath,
              icon: const Icon(Icons.folder_open),
              label: const Text("SELECT FOLDER"),
            ),
            
            const SizedBox(height: 40),
            
            ElevatedButton(
              onPressed: _selectedPath != null ? _continue : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
              child: const Text("START INSTALLATION", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}