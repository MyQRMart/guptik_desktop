import 'package:flutter/material.dart';
import 'package:guptik_desktop/services/supabase_service.dart';
import '../../services/external/docker_service.dart';
import '../dashboard/dashboard_screen.dart';

class InstallationScreen extends StatefulWidget {
  final String deviceId;
  final String vaultPath;

  const InstallationScreen({super.key, required this.deviceId, required this.vaultPath});

  @override
  State<InstallationScreen> createState() => _InstallationScreenState();
}

class _InstallationScreenState extends State<InstallationScreen> {
  final DockerService _dockerService = DockerService();
  final List<String> _logs = [];
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    // Initialize the path in DockerService immediately
    _dockerService.setVaultPath(widget.vaultPath);
    _runInstallation();
  }

  void _addLog(String msg) {
    if (mounted) {
      setState(() => _logs.add("[${DateTime.now().toLocal().toString().split(' ')[1].substring(0,8)}] $msg"));
    }
  }

  Future<void> _runInstallation() async {
    _addLog("Waiting for Cloudflare Tunnel provisioning...");
    
    try {
      String? token;
      String? publicUrl;
      
      // 1. Poll Supabase for up to 30 seconds to get the token
      for (int i = 0; i < 15; i++) {
        final config = await SupabaseService().getTunnelConfig(widget.deviceId);
        
        if (config != null && config['cf_tunnel_token'] != null) {
          token = config['cf_tunnel_token'];
          publicUrl = config['public_url'];
          break; // Found it, exit the loop
        }
        
        _addLog("Checking database... (${i + 1}/15)");
        await Future.delayed(const Duration(seconds: 2));
      }

      if (token == null || publicUrl == null) {
        throw Exception("Timeout: Could not retrieve Tunnel data from Supabase.");
      }
      
      _addLog("Tunnel configuration found: $publicUrl");

      // 2. Configure local environment files
      _addLog("Writing Docker configurations to local path...");
      await _dockerService.autoConfigure(
        dbPass: "guptik_secure_db",
        tunnelToken: token,
        publicUrl: publicUrl,
      );

      // 3. Start the Docker Stack
      _addLog("Launching Docker containers (Ollama, Kong, Postgres)...");
      await _dockerService.startStack();

      _addLog("SUCCESS: Installation Complete!");
      setState(() => _isFinished = true);

    } catch (e) {
      _addLog("ERROR: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            const Text(
              "GUPTIK CORE INSTALLATION", 
              style: TextStyle(color: Colors.cyanAccent, fontSize: 24, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111), 
                  borderRadius: BorderRadius.circular(8), 
                  border: Border.all(color: Colors.white10)
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, i) => Text(
                    _logs[i], 
                    style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier')
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            if (_isFinished)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacement(
                    context, 
                    MaterialPageRoute(builder: (_) => const DashboardScreen())
                  ),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent),
                  child: const Text("OPEN DASHBOARD", style: TextStyle(color: Colors.black)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}