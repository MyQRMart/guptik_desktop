import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/external/docker_service.dart';
import '../../services/external/postgres_service.dart';
import '../home_control/home_control_screen.dart';
import 'login_signup_screen.dart';
import '../../services/supabase_service.dart';
import '../../services/node/node_presence_service.dart';
import '../../services/updates/update_service.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  String _status = 'Waking up GupTik Core...';

  void _set(String s) {
    if (mounted) setState(() => _status = s);
  }
  @override
  void initState() {
    super.initState();
    _initializeSystem();
  }

  Future<void> _initializeSystem() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var vaultPath = prefs.getString('vault_path');
      final email = prefs.getString('user_email');
      final password = prefs.getString('user_password');

      if (vaultPath == null) {
        final existing = await DockerService.findExistingStack();
        if (existing != null) {
          vaultPath = existing.workingDir;
          await prefs.setString('vault_path', vaultPath);
          await DockerService.rememberVault(vaultPath);
        }
      }

      if (vaultPath == null || email == null || password == null) {
        throw Exception("Corrupt session data");
      }

      // 1. Check basic Supabase Auth Session
      final supabaseService = SupabaseService();
      if (supabaseService.currentUserId == null) {
        throw Exception("Cloud session expired. Please log in again.");
      }

      // 2. Re-link Docker Service to the correct path
      DockerService().setVaultPath(vaultPath);

      // 3. Re-connect to Postgres (Retries in case Docker is still booting)
      int retries = 0;
      bool connected = false;
      while (retries < 15) {
        try {
          await PostgresService().connectExistingUser(
            email: email,
            userPassword: password,
          );
          connected = true;
          break;
        } catch (e) {
          retries++;
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (!connected) throw Exception("Could not reach local database.");

      if (UpdateService.nodeNeedsUpdate(vaultPath)) {
        _set('Updating node (no reinstall)...');
        try {
          await DockerService().applyNodeUpdate();
        } catch (e) {
          print('Node update: $e');
        }
      }

      await NodePresenceService.instance.start();

      // 4. Go to Home Control (which now has the Dashboard as first tab)
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeControlScreen()),
        );
      }
    } catch (e) {
      print("Boot Error: $e");
      // Fallback to Login
      if (mounted) {
        Navigator.pushReplacement(
          context,
MaterialPageRoute(builder: (_) => const LoginSignupScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'lib/assets/logonobg.png',
              height: 80,
              errorBuilder: (_, _, _) => const Icon(
                Icons.security,
                size: 80,
                color: Colors.cyanAccent,
              ),
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.cyanAccent),
            const SizedBox(height: 20),
            Text(
              _status,
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontFamily: 'Courier',
                letterSpacing: 1,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}