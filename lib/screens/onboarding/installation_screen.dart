import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    _addLog("Initializing Cloudflare Tunnel via Edge Function...");
    
    try {
      // 1. Invoke the Edge Function
      final FunctionResponse response = await Supabase.instance.client.functions.invoke(
        'user-cf-tunnel', 
        body: {'device_id': widget.deviceId},
      );

      // Handle potential null or error responses
      if (response.data == null) throw Exception("Empty response from Edge Function");
      
      final String? token = response.data['tunnelToken'];
      final String? publicUrl = response.data['publicUrl'];
      
      if (token == null || publicUrl == null) {
        throw Exception("Missing tunnel data in response");
      }
      
      _addLog("Tunnel provisioned: $publicUrl");

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

      // 4. Update the device status in Supabase
      await Supabase.instance.client
          .from('desktop_devices')
          .update({
            'installation_status': 'completed', 
            'public_url': publicUrl,
            'cf_tunnel_token': token // Store token for recovery
          })
          .eq('device_id', widget.deviceId);

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