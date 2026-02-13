import 'dart:io';
import 'package:flutter/material.dart';
import 'package:process_run/shell.dart';
import '../dashboard/dashboard_screen.dart'; // We will build this later

class InstallationScreen extends StatefulWidget {
  final String deviceId;
  final String systemPath;

  const InstallationScreen({super.key, required this.deviceId, required this.systemPath});

  @override
  State<InstallationScreen> createState() => _InstallationScreenState();
}

class _InstallationScreenState extends State<InstallationScreen> {
  final Shell _shell = Shell();
  List<String> _logs = [];
  bool _isDockerInstalled = false;
  bool _isInstalling = false;

  @override
  void initState() {
    super.initState();
    _startInstallationProcess();
  }


  void _addLog(String message) {
    setState(() => _logs.add("[${DateTime.now().toIso8601String().split('T')[1].split('.')[0]}] $message"));
  }

  Future<void> _startInstallationProcess() async {
    _addLog("Checking system requirements...");
    
    // 1. Check Docker
    try {
      await _shell.run('docker --version');
      setState(() => _isDockerInstalled = true);
      _addLog("Docker found. Proceeding...");
    } catch (e) {
      _addLog("ERROR: Docker not found! Please install Docker Desktop.");
      return;
    }

    // 2. Create docker-compose.yml
    _addLog("Generating configuration files...");
    await _createComposeFile();

    // 3. Run Docker Compose
    setState(() => _isInstalling = true);
    _addLog("Pulling images (Supabase, n8n, Ollama)... This may take a while.");
    
    try {
      // Change directory to systemPath and run compose
      // Note: In a real app, use 'workingDirectory' parameter of shell
      var controller = Shell(workingDirectory: widget.systemPath);
      
      await controller.run('docker-compose up -d');
      _addLog("SUCCESS: All services are running!");
      
      // 4. Finish
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }
      
    } catch (e) {
      _addLog("CRITICAL ERROR during installation: $e");
    }
  }

  Future<void> _createComposeFile() async {
    final file = File('${widget.systemPath}/docker-compose.yml');
    
    // This is a simplified stack for the user
    // We mount volumes to the path the user selected
    final content = '''
version: '3.8'
services:
  # 1. Local Database (Supabase replacement/cache)
  postgres:
    image: postgres:15
    volumes:
      - ./db_data:/var/lib/postgresql/data
    environment:
      POSTGRES_PASSWORD: secure_password
      POSTGRES_DB: guptik_local
    ports:
      - "5432:5432"

  # 2. Automation (n8n)
  n8n:
    image: docker.n8n.io/n8nio/n8n
    ports:
      - "5678:5678"
    volumes:
      - ./n8n_data:/home/node/.n8n
    environment:
      - N8N_HOST=localhost

  # 3. AI Engine (Ollama)
  ollama:
    image: ollama/ollama
    volumes:
      - ./ollama_data:/root/.ollama
    ports:
      - "11434:11434"
      
  # 4. Cloudflared (For your Domain Logic)
  tunnel:
    image: cloudflare/cloudflared
    command: tunnel run
    environment:
      - TUNNEL_TOKEN=\${TUNNEL_TOKEN} # You will inject this later from settings
''';
    
    await file.writeAsString(content);
    _addLog("Configuration written to: ${file.path}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("INSTALLING GUPTIK CORE", style: TextStyle(color: Colors.cyanAccent, fontSize: 24, fontFamily: 'Courier', fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: _isInstalling ? null : 0.1, // Indeterminate when installing
              backgroundColor: Colors.grey[900],
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 30),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      _logs[index],
                      style: const TextStyle(color: Colors.greenAccent, fontFamily: 'Courier', fontSize: 14),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}