import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'dart:math';
import 'package:guptik_desktop/services/supabase_service.dart';
import 'package:guptik_desktop/services/node/node_presence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../onboarding/storage_selection_screen.dart';
import '../onboarding/installation_screen.dart';
import '../home_control/home_control_screen.dart';
import '../../services/external/docker_service.dart';
import '../../services/external/postgres_service.dart';

class LoginSignupScreen extends StatefulWidget {
  const LoginSignupScreen({super.key});

  @override
  State<LoginSignupScreen> createState() => _LoginSignupScreenState();
}

class _LoginSignupScreenState extends State<LoginSignupScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  
  bool _isLoading = false;
  String _statusMessage = ""; 
  String? _errorMessage;
  String? _deviceId;
  bool _isLoginMode = true; // Toggle between login and signup

  @override
  void initState() {
    super.initState();
    _loadDeviceId();
  }

  Future<void> _loadDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString('desktop_device_id');
    id ??= _generateRandomId(12);
    await prefs.setString('desktop_device_id', id);
    if (mounted) setState(() => _deviceId = id);
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
      await NodePresenceService.instance.start();

      // 3. Trigger Cloudflare Tunnel Creation
      setState(() => _statusMessage = "Requesting Secure Tunnel...");
      await SupabaseService().triggerN8nWebhook(_deviceId!);

      // 4. Poll for Tunnel Token (Wait for n8n to finish)
      setState(() => _statusMessage = "Initializing Connection (this may take 10-20s)...");
      var tunnelData = await _waitForTunnelToken(_deviceId!);

      if (tunnelData == null) {
        final lan = await NodePresenceService.lanUrl();
        tunnelData = {'cf_tunnel_token': '', 'public_url': lan};
        setState(() => _statusMessage = "Tunnel pending — using LAN $lan");
      }
      final tunnel = tunnelData!;

      // 5. Reuse existing node if this PC already has one
      await _openNode(
        email: email,
        password: password,
        cfToken: tunnel['cf_tunnel_token']?.toString() ?? '',
        publicUrl: tunnel['public_url']?.toString() ?? '',
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception:', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignup() async {
    if (_deviceId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _statusMessage = "Creating account...";
    });

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      // Validate inputs
      if (name.isEmpty) throw Exception("Please enter your name");
      if (email.isEmpty) throw Exception("Please enter your email");
      if (password.isEmpty) throw Exception("Please enter a password");
      if (password != confirmPassword) throw Exception("Passwords do not match");
      if (password.length < 6) throw Exception("Password must be at least 6 characters");

      // 1. Create User in Supabase
      final AuthResponse res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
        },
      );

      if (res.user == null) throw Exception("Signup failed. Please try again.");

      // 2. Register Device
      setState(() => _statusMessage = "Registering Device...");
      final deviceModel = await _getDeviceModel();

      await SupabaseService().registerDesktopDevice(
        deviceId: _deviceId!,
        userId: res.user!.id,
        modelName: deviceModel,
      );
      await NodePresenceService.instance.start();

      // 3. Trigger Cloudflare Tunnel Creation
      setState(() => _statusMessage = "Requesting Secure Tunnel...");
      await SupabaseService().triggerN8nWebhook(_deviceId!);

      // 4. Poll for Tunnel Token (Wait for n8n to finish)
      setState(() => _statusMessage = "Initializing Connection (this may take 10-20s)...");
      var tunnelData = await _waitForTunnelToken(_deviceId!);

      if (tunnelData == null) {
        final lan = await NodePresenceService.lanUrl();
        tunnelData = {'cf_tunnel_token': '', 'public_url': lan};
        setState(() => _statusMessage = "Tunnel pending — using LAN $lan");
      }
      final tunnel = tunnelData!;

      // 5. Reuse existing node if this PC already has one
      await _openNode(
        email: email,
        password: password,
        cfToken: tunnel['cf_tunnel_token']?.toString() ?? '',
        publicUrl: tunnel['public_url']?.toString() ?? '',
      );
    } catch (e) {
      setState(() => _errorMessage = e.toString().replaceAll('Exception:', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openNode({
    required String email,
    required String password,
    required String cfToken,
    required String publicUrl,
  }) async {
    final existing = await DockerService.findExistingStack();
    if (existing != null) {
      setState(() => _statusMessage = existing.running
          ? "Found running GupTik node — reconnecting..."
          : "Found existing GupTik node — attaching...");
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_logged_in', true);
      await prefs.setString('vault_path', existing.workingDir);
      await prefs.setString('user_email', email);
      await prefs.setString('user_password', password);
      await DockerService.rememberVault(existing.workingDir);
      DockerService().setVaultPath(existing.workingDir);
      if (!existing.running || !await DockerService.gatewayUp()) {
        await DockerService().startStack(build: false);
      }
      try {
        await PostgresService().connectExistingUser(email: email, userPassword: password);
      } catch (_) {
        await PostgresService().initializeUserDatabase(email: email, userPassword: password);
      }
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeControlScreen()));
      return;
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => StorageSelectionScreen(
          deviceId: _deviceId!,
          userEmail: email,
          userPassword: password,
          cfToken: cfToken,
          publicUrl: publicUrl,
        ),
      ),
    );
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
                  Image.asset('lib/assets/logonobg.png', height: 40, errorBuilder: (_,_,_) => const Icon(Icons.security, color: Colors.cyanAccent, size: 40)),
                  const SizedBox(width: 15),
                  const Text("GUPTIK CORE", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Colors.white)),
                ],
              ),
              const SizedBox(height: 30),

              // Toggle between Login and Signup
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isLoginMode = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _isLoginMode ? Colors.cyanAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            "LOGIN",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _isLoginMode = false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: !_isLoginMode ? Colors.cyanAccent : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: Text(
                            "SIGN UP",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 25),

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

              // Name field (only for signup)
              if (!_isLoginMode) ...[
                const Text("FULL NAME", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Enter your full name", Icons.person_outline),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 20),
              ],

              // Email field
              const Text("IDENTITY", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Email Address", Icons.alternate_email),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 20),

              // Password field
              const Text("CREDENTIAL", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Password", Icons.lock_outline),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 20),

              // Confirm Password field (only for signup)
              if (!_isLoginMode) ...[
                const Text("CONFIRM CREDENTIAL", style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration("Confirm Password", Icons.lock_outline),
                  enabled: !_isLoading,
                ),
                const SizedBox(height: 30),
              ],

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
                    onPressed: _isLoginMode ? _handleLogin : _handleSignup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      _isLoginMode ? "INITIALIZE SYSTEM" : "CREATE ACCOUNT",
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Toggle text
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isLoginMode = !_isLoginMode),
                  child: Text(
                    _isLoginMode 
                        ? "Don't have an account? Sign Up" 
                        : "Already have an account? Log In",
                    style: const TextStyle(color: Colors.cyanAccent),
                  ),
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