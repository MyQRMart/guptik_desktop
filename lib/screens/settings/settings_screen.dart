import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/storage_service.dart';
import '../auth/qr_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();
  String? _deviceId;
  String? _userId;
  String? _publicUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final deviceId = await _storage.getDeviceId();
    final userId = await _storage.getUserId();
    final publicUrl = await _storage.getPublicUrl();

    if (mounted) {
      setState(() {
        _deviceId = deviceId;
        _userId = userId;
        _publicUrl = publicUrl;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleFactoryReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Factory Reset?", style: TextStyle(color: Colors.redAccent)),
        content: const Text(
          "This will disconnect this device from your account. Local files will remain, but remote access will be disabled.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("RESET"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _storage.clearSession();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushReplacement(
          MaterialPageRoute(builder: (_) => const QrLoginScreen()),
        );
      }
    }
  }

  Widget _buildInfoCard(String title, String value, IconData icon, {bool isLink = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.cyanAccent, size: 28),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 5),
                SelectableText(
                  value,
                  style: TextStyle(
                    color: isLink ? Colors.blueAccent : Colors.white,
                    fontSize: 16,
                    fontFamily: 'Courier',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy, color: Colors.white24),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Copied $title")),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    // Construct Service URLs
    final baseUrl = "https://$_publicUrl";
    final vaultLink = "$baseUrl/vault/files/";
    final guptikLink = "$baseUrl/guptik/chat";
    final trustMeLink = "$baseUrl/trust_me/status";

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: ListView(
        padding: const EdgeInsets.all(40),
        children: [
          const Text(
            "SYSTEM SETTINGS",
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "Manage your sovereign node configuration",
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 50),

          const Text("DEVICE IDENTITY", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _buildInfoCard("Device ID", _deviceId ?? "Unknown", Icons.computer),
          _buildInfoCard("Owner User ID", _userId ?? "Unknown", Icons.person_outline),

          const SizedBox(height: 40),
          const Text("PUBLIC SERVICE ENDPOINTS", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          _buildInfoCard("Gateway Root", baseUrl, Icons.dns, isLink: true),
          _buildInfoCard("Vault Storage API", vaultLink, Icons.storage, isLink: true),
          _buildInfoCard("Guptik AI Agent", guptikLink, Icons.psychology, isLink: true),
          _buildInfoCard("Trust Me Secure Channel", trustMeLink, Icons.security, isLink: true),

          const SizedBox(height: 50),
          Center(
            child: SizedBox(
              width: 300,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  side: const BorderSide(color: Colors.red),
                  foregroundColor: Colors.red,
                ),
                icon: const Icon(Icons.delete_forever),
                label: const Text("FACTORY RESET & DISCONNECT"),
                onPressed: _handleFactoryReset,
              ),
            ),
          ),
        ],
      ),
    );
  }
}