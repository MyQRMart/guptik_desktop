import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart'; // Add to pubspec.yaml
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_selection_screen.dart';

class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen> {
  String? _deviceId;
  String? _deviceModel;
  bool _isWaiting = true;

  @override
  void initState() {
    super.initState();
    _initializePairing();
  }

  // 1. Generate ID & Get System Info
  Future<void> _initializePairing() async {
    final deviceInfo = DeviceInfoPlugin();
    String model = "Unknown PC";
    
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

    setState(() {
      _deviceModel = model;
      _deviceId = _generateRandomId(12); // e.g., "A1B2-C3D4-E5F6"
    });

    // 2. Start Listening to Supabase for this Specific ID
    _listenForMobileConfirmation();
  }

  String _generateRandomId(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  void _listenForMobileConfirmation() {
    // We listen to the 'desktop_devices' table.
    // The Mobile App will INSERT a row with this _deviceId and the user's UUID.
    // Once we see that row, we know who the user is.

    Supabase.instance.client
        .from('desktop_devices')
        .stream(primaryKey: ['id'])
        .eq('device_id', _deviceId!)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty) {
            final device = data.first;
            if (device['is_verified'] == true) {
              // Login Success! Save User ID locally if needed
              if (mounted) {
                Navigator.pushReplacement(
                  context, 
                  MaterialPageRoute(builder: (_) => StorageSelectionScreen(deviceId: _deviceId!))
                );
              }
            }
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    // JSON Data the Mobile App needs to scan
    final String qrData = '{"id":"$_deviceId", "model":"$_deviceModel", "type":"desktop_setup"}';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("LINK TO MOBILE", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Text("Scan this with your Guptik Mobile App", style: TextStyle(color: Colors.grey[400])),
            const SizedBox(height: 40),
            
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: _deviceId == null 
                  ? const CircularProgressIndicator()
                  : QrImageView(data: qrData, size: 280, version: QrVersions.auto),
            ),
            
            const SizedBox(height: 30),
            if (_deviceId != null)
              Text("Device ID: $_deviceId", style: const TextStyle(fontFamily: 'Courier', fontSize: 24, letterSpacing: 4, color: Colors.cyanAccent)),
            
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.cyanAccent),
            const SizedBox(height: 10),
            const Text("Waiting for connection...", style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}