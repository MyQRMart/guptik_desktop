import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// If you have the storage selection screen ready, import it:
// import '../onboarding/storage_selection_screen.dart';

class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen> {
  String? _qrData;
  String? _deviceId;
  
  @override
  void initState() {
    super.initState();
    _generateQrData();
  }

  Future<void> _generateQrData() async {
    final deviceInfo = DeviceInfoPlugin();
    String model = "Unknown PC";
    
    // 1. Get Device Name
    if (Platform.isLinux) {
      final linuxInfo = await deviceInfo.linuxInfo;
      model = "${linuxInfo.name} (${linuxInfo.versionId})";
    } else if (Platform.isWindows) {
      final winInfo = await deviceInfo.windowsInfo;
      model = winInfo.productName;
    } else if (Platform.isMacOS) {
      final macInfo = await deviceInfo.macOsInfo;
      model = macInfo.model;
    }

    // 2. Generate Unique ID
    _deviceId = _generateRandomId(12);

    // 3. Create JSON String
    // This is what the mobile app needs to scan
    setState(() {
      _qrData = '{"device_id":"$_deviceId", "model":"$model"}';
    });

    // 4. Start Listening (Optional: uncomment when ready)
    // _listenForLogin();
  }

  String _generateRandomId(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.computer, size: 60, color: Colors.cyanAccent),
            const SizedBox(height: 20),
            const Text(
              "SCAN TO PAIR", 
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)
            ),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _qrData == null 
                ? const CircularProgressIndicator()
                : QrImageView(
                    data: _qrData!,
                    version: QrVersions.auto,
                    size: 250.0,
                  ),
            ),
            const SizedBox(height: 20),
            if (_qrData != null)
              // Only showing the ID for user reference, not the full JSON
              Text("ID: $_deviceId", style: const TextStyle(color: Colors.grey, fontFamily: 'Courier')),
          ],
        ),
      ),
    );
  }
}