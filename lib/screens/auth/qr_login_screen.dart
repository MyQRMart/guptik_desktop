import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dashboard/dashboard_screen.dart';

class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen> {
  String? _sessionToken;
  
  @override
  void initState() {
    super.initState();
    _generateSessionToken();
    _listenForMobileAuth();
  }

  void _generateSessionToken() {
    // In reality, generate a UUID
    setState(() {
      _sessionToken = "AUTH-${DateTime.now().millisecondsSinceEpoch}";
    });
  }

  void _listenForMobileAuth() {
    // Subscribe to Supabase Realtime
    // When mobile app scans QR, it inserts a record into 'desktop_devices'
    // with this token. We listen for that confirmation.
    
    // Simulating login for now:
    Supabase.instance.client
        .from('desktop_devices')
        .stream(primaryKey: ['id'])
        .eq('device_id', _sessionToken!)
        .listen((data) {
          if (data.isNotEmpty && data.first['is_trusted'] == true) {
             Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (_) => const DashboardScreen())
            );
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield, size: 80, color: Colors.cyanAccent),
            const SizedBox(height: 30),
            const Text(
              "SCAN TO UNLOCK", 
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 5)
            ),
            const SizedBox(height: 10),
            const Text("Open your Mobile App > Settings > Link Desktop"),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: _sessionToken == null 
                ? const CircularProgressIndicator()
                : QrImageView(
                    data: _sessionToken!,
                    version: QrVersions.auto,
                    size: 250.0,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}