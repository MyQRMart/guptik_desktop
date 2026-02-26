import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/external/docker_service.dart';
import '../../services/external/postgres_service.dart';
import '../dashboard/dashboard_screen.dart';
import 'login_screen.dart';

class BootScreen extends StatefulWidget {
  const BootScreen({super.key});

  @override
  State<BootScreen> createState() => _BootScreenState();
}

class _BootScreenState extends State<BootScreen> {
  @override
  void initState() {
    super.initState();
    _initializeSystem();
  }

  Future<void> _initializeSystem() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final vaultPath = prefs.getString('vault_path');
      final email = prefs.getString('user_email');
      final password = prefs.getString('user_password');

      if (vaultPath == null || email == null || password == null) {
        throw Exception("Corrupt session data");
      }

      // 1. Re-link Docker Service to the correct path
      DockerService().setVaultPath(vaultPath);

      // 2. Re-connect to Postgres (Retries in case Docker is still booting)
      int retries = 0;
      bool connected = false;
      while (retries < 15) {
        try {
          await PostgresService().connectExistingUser(email: email, userPassword: password);
          connected = true;
          break;
        } catch (e) {
          retries++;
          await Future.delayed(const Duration(seconds: 2));
        }
      }

      if (!connected) throw Exception("Could not reach local database.");

      // 3. Go to Dashboard
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
      }

    } catch (e) {
      print("Boot Error: $e");
      // If something fails critically, fallback to Login
      if (mounted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // Clear bad data
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
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
            Image.asset('lib/assets/logonobg.png', height: 80, errorBuilder: (_,__,___) => const Icon(Icons.security, size: 80, color: Colors.cyanAccent)),
            const SizedBox(height: 30),
            const CircularProgressIndicator(color: Colors.cyanAccent),
            const SizedBox(height: 20),
            const Text("Waking up Guptik Core...", style: TextStyle(color: Colors.cyanAccent, fontFamily: 'Courier', letterSpacing: 2)),
          ],
        ),
      ),
    );
  }
}