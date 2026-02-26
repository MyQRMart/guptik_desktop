import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:math';
import 'package:guptik_desktop/services/supabase_service.dart';
import '../onboarding/storage_selection_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  String _statusMessage = ""; 
  String? _errorMessage;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _deviceId = _generateRandomId(12);
  }

  String _generateRandomId(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<void> _handleLogin() async {
    if (_deviceId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = "Authenticating...";
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();

      // 1. Supabase Auth
      final AuthResponse res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.user == null) throw Exception("Login failed. Please check credentials.");

      // 2. Register Device
      setState(() => _statusMessage = "Registering Device...");
      final deviceModel = await _getDeviceModel();

      await SupabaseService().registerDesktopDevice(
        deviceId: _deviceId!,
        userId: res.user!.id,
        modelName: deviceModel,
      );

      // 3. Trigger Cloudflare Tunnel Creation
      setState(() => _statusMessage = "Requesting Secure Tunnel...");
      await SupabaseService().triggerN8nWebhook(_deviceId!);

      // 4. Poll for Tunnel Token (Wait for n8n to finish)
      setState(() => _statusMessage = "Initializing Connection (this may take 10-20s)...");
      final tunnelData = await _waitForTunnelToken(_deviceId!);

      if (tunnelData == null) {
        throw Exception("Connection timed out. Cloudflare Tunnel could not be provisioned.");
      }

      // 5. Success -> Navigate to Storage Selection
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => StorageSelectionScreen(
              deviceId: _deviceId!,
              userEmail: email,
              userPassword: password,
              cfToken: tunnelData['cf_tunnel_token'], 
              publicUrl: tunnelData['public_url'],    
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception:', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Map<String, dynamic>?> _waitForTunnelToken(String deviceId) async {
    for (int i = 0; i < 30; i++) {
      final config = await SupabaseService().getTunnelConfig(deviceId);
      
      if (config != null && config['cf_tunnel_token'] != null && config['public_url'] != null) {
        return config; 
      }
      
      await Future.delayed(const Duration(seconds: 2));
    }
    return null; 
  }

  Future<String> _getDeviceModel() async {
    if (Platform.isWindows) return (await DeviceInfoPlugin().windowsInfo).productName;
    if (Platform.isLinux) return (await DeviceInfoPlugin().linuxInfo).name;
    if (Platform.isMacOS) return (await DeviceInfoPlugin().macOsInfo).model;
    return "Unknown Desktop";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              )
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Image.asset('lib/assets/logonobg.png', height: 40, errorBuilder: (_,__,___) => const Icon(Icons.security, color: Colors.cyanAccent, size: 40)),
                  const SizedBox(width: 15),
                  const Text("GUPTIK CORE", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 30),

              // Device ID Display
              if (_deviceId != null)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  margin: const EdgeInsets.only(bottom: 25),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.computer, color: Colors.cyanAccent, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        "DEVICE ID: $_deviceId",
                        style: const TextStyle(
                          color: Colors.cyanAccent, 
                          fontFamily: 'Courier', 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Error Message
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
                  ]),
                ),

              // Inputs
              const Text("IDENTITY", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Email Address", Icons.alternate_email),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 20),
              const Text("CREDENTIAL", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Password", Icons.lock_outline),
                enabled: !_isLoading,
              ),

              const SizedBox(height: 30),
              
              // Status & Action
              if (_isLoading)
                Column(
                  children: [
                    const LinearProgressIndicator(color: Colors.cyanAccent, backgroundColor: Colors.white10),
                    const SizedBox(height: 15),
                    Text(_statusMessage, style: const TextStyle(color: Colors.cyanAccent, fontSize: 13, fontFamily: 'Courier')),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("INITIALIZE SYSTEM", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[600]),
      prefixIcon: Icon(icon, color: Colors.cyanAccent.withOpacity(0.7)),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.cyanAccent)),
    );
  }
}