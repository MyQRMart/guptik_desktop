import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:guptik_desktop/services/supabase_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../onboarding/storage_selection_screen.dart';

class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen> {
  String? _deviceId;
  String? _deviceModel;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _initializePairing();
  }

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
      _deviceId = _generateRandomId(12);
    });

    _listenForMobileConfirmation();
  }

  String _generateRandomId(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
      length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  void _listenForMobileConfirmation() {
    if (_deviceId == null) return;
    Supabase.instance.client
        .from('desktop_devices')
        .stream(primaryKey: ['id'])
        .eq('device_id', _deviceId!)
        .listen((List<Map<String, dynamic>> data) {
          if (data.isNotEmpty && data.first['user_id'] != null) {
            _handleLoginSuccess(data.first);
          }
        });
  }

  Future<void> _manualCheck() async {
    if (_deviceId == null) return;
    setState(() => _isChecking = true);
    
    try {
      print("Checking database for Device ID: $_deviceId");
      // 1. Verify the mobile app successfully inserted the record
      final response = await Supabase.instance.client
          .from('desktop_devices')
          .select('user_id')
          .eq('device_id', _deviceId!)
          .maybeSingle();

      if (response != null && response['user_id'] != null) {
        print("User linked! Triggering provisioning...");
        // 2. Trigger n8n in the background
        await SupabaseService().triggerN8nWebhook(_deviceId!);
        
        // 3. Move to Storage Selection
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => StorageSelectionScreen(deviceId: _deviceId!)),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Device not linked yet. Please scan with the mobile app first.")),
        );
      }
    } catch (e) {
      print("Check error: $e");
    } finally {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _handleLoginSuccess(Map<String, dynamic> device) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('device_id', _deviceId!);
    if (device['user_id'] != null) await prefs.setString('user_uid', device['user_id']);

    if (mounted) {
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => StorageSelectionScreen(deviceId: _deviceId!))
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String qrData = '{"device_id":"$_deviceId", "model":"$_deviceModel", "type":"desktop_setup"}';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("LINK TO MOBILE", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 10),
            Text("Scan with Guptik Mobile App", style: TextStyle(color: Colors.grey[400])),
            const SizedBox(height: 40),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: _deviceId == null 
                  ? const CircularProgressIndicator()
                  : QrImageView(data: qrData, size: 280, version: QrVersions.auto),
            ),
            const SizedBox(height: 15), // Space below the QR code
            // --- ADD THIS BLOCK ---
            if (_deviceId != null)
              Text(
                "DEVICE ID: $_deviceId",
                style: const TextStyle(
                  color: Colors.cyanAccent, 
                  fontFamily: 'Courier', 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
            const SizedBox(height: 35),
            SizedBox(
              width: 250,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _isChecking ? null : _manualCheck,
                icon: _isChecking 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline, color: Colors.black),
                label: const Text("I'VE SCANNED IT", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}