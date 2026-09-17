import 'dart:async';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Publishes this PC as the user's home node so mobile (same account) can find it.
class NodePresenceService {
  NodePresenceService._();
  static final NodePresenceService instance = NodePresenceService._();

  Timer? _beat;
  String? deviceId;

  Future<void> start() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    deviceId = prefs.getString('desktop_device_id');
    if (deviceId == null || deviceId!.isEmpty) {
      deviceId = DateTime.now().millisecondsSinceEpoch.toRadixString(36).toUpperCase();
      await prefs.setString('desktop_device_id', deviceId!);
    }
    await announce();
    _beat?.cancel();
    _beat = Timer.periodic(const Duration(seconds: 30), (_) => announce());
  }

  void stop() {
    _beat?.cancel();
    _beat = null;
  }

  static Future<String> lanUrl() async {
    try {
      for (final ni in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      )) {
        for (final a in ni.addresses) {
          if (!a.isLoopback) return 'http://${a.address}:55000';
        }
      }
    } catch (e) {
      debugPrint('lanUrl: $e');
    }
    return 'http://127.0.0.1:55000';
  }

  Future<String> _model() async {
    try {
      if (Platform.isLinux) return (await DeviceInfoPlugin().linuxInfo).prettyName;
      if (Platform.isWindows) return (await DeviceInfoPlugin().windowsInfo).productName;
      if (Platform.isMacOS) return (await DeviceInfoPlugin().macOsInfo).model;
    } catch (_) {}
    return 'GupTik Desktop';
  }

  Future<void> announce() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || deviceId == null) return;
    final lan = await lanUrl();
    final model = await _model();
    final prefs = await SharedPreferences.getInstance();
    final storedTunnel = prefs.getString('public_url') ?? '';

    try {
      final existing = await Supabase.instance.client
          .from('desktop_devices')
          .select('public_url')
          .eq('device_id', deviceId!)
          .maybeSingle();
      final current = (existing?['public_url'] ?? '').toString().trim();
      final looksTunnel = current.contains('guptik.myqrmart.com') || current.startsWith('https://');
      final publicUrl = looksTunnel
          ? current
          : (storedTunnel.isNotEmpty ? storedTunnel : lan);

      await Supabase.instance.client.from('desktop_devices').upsert({
        'device_id': deviceId,
        'user_id': user.id,
        'device_model': model,
        'status': 'online',
        'installation_status': 'completed',
        'is_verified': true,
        'last_active_at': DateTime.now().toUtc().toIso8601String(),
        'public_url': publicUrl,
      }, onConflict: 'device_id');

      try {
        await Supabase.instance.client.from('mp_channels').upsert({
          'channel_id': user.id,
          'owner_uid': user.id,
          'user_id': user.id,
          'channel_name': 'My Channel',
          'tunnel_url': publicUrl,
        }, onConflict: 'channel_id');
      } catch (e) {
        debugPrint('mp_channels announce: $e');
      }
    } catch (e) {
      debugPrint('NodePresence announce: $e');
    }
  }
}
