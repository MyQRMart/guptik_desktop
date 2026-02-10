import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../onboarding/storage_selection_screen.dart'; // Ensure this import path is correct

class QrLoginScreen extends StatefulWidget {
  const QrLoginScreen({super.key});

  @override
  State<QrLoginScreen> createState() => _QrLoginScreenState();
}

class _QrLoginScreenState extends State<QrLoginScreen> {
  String? _qrData;
  String? _deviceId;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _generateQrData();
  }

  Future<void> _generateQrData() async {
    final deviceInfo = DeviceInfoPlugin();
    String model = "Unknown PC";

    try {
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
    } catch (e) {
      print("Error getting device info: $e");
    }

    // Generate a clean 12-char ID
    _deviceId = _generateRandomId(12);

    if (mounted) {
      setState(() {
        // This JSON is what the mobile app scans
        _qrData = '{"device_id":"$_deviceId", "model":"$model"}';
      });
    }
  }

  String _generateRandomId(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  /// 1. CHECK SUPABASE FOR VERIFICATION
  Future<void> _checkConnection() async {
    if (_deviceId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Query the desktop_devices table for this specific Device ID
      final response = await Supabase.instance.client
          .from('desktop_devices')
          .select()
          .eq('device_id', _deviceId!)
          .maybeSingle();

      if (response != null) {
        final data = response as Map<String, dynamic>;
        
        // Check if verified or if user_id is present
        if (data['user_id'] != null) {
          final String userId = data['user_id'];
          print("Connection Verified! User ID: $userId");
          
          // 2. SAVE USER ID LOCALLY (So we don't scan every time)
          await _saveUserSession(userId, _deviceId!);

          // 3. NAVIGATE TO NEXT SCREEN
          if (mounted) {
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (_) => StorageSelectionScreen(deviceId: _deviceId!))
            );
          }
        } else {
          setState(() {
            _errorMessage = "Device found, but not verified by mobile yet.";
          });
        }
      } else {
        setState(() {
          _errorMessage = "Waiting... Please scan the QR code with your mobile app.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Connection Error: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Saves the User ID and Device ID to a local JSON file
  Future<void> _saveUserSession(String userId, String deviceId) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/guptik_session.json');
      final sessionData = jsonEncode({
        'user_id': userId,
        'device_id': deviceId,
        'logged_in_at': DateTime.now().toIso8601String(),
      });
      await file.writeAsString(sessionData);
      print("Session saved to ${file.path}");
    } catch (e) {
      print("Failed to save session: $e");
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
            const Icon(Icons.desktop_windows, size: 60, color: Colors.cyanAccent),
            const SizedBox(height: 20),
            const Text(
              "PAIR WITH MOBILE", 
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)
            ),
            const SizedBox(height: 40),
            
            // QR Code Container
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.cyanAccent.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)
                ]
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
            if (_deviceId != null)
              Text("ID: $_deviceId", style: const TextStyle(color: Colors.grey, fontFamily: 'Courier', fontSize: 16)),
            
            const SizedBox(height: 40),

            // ERROR MESSAGE
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent)),
              ),

            // VERIFY BUTTON
            SizedBox(
              width: 250,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _checkConnection,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.black) 
                  : const Text("I HAVE SCANNED IT", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}