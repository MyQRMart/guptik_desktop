import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'node_http.dart';
import 'node_presence_service.dart';

class PairedDevice {
  PairedDevice({required this.id, required this.name, this.lastSeen, this.revoked = false});
  final String id;
  final String name;
  final DateTime? lastSeen;
  final bool revoked;
}

/// Mints per-phone tokens through the owner-only /admin/devices routes of this PC's gateway.
class NodePairing {
  NodePairing._();
  static const _base = 'http://localhost:55000';

  /// Creates a device token and returns the `guptik://pair` link that goes into the QR code.
  /// The token is shown once; the gateway stores only its hash.
  static Future<({String link, String deviceId})> mintLink(String phoneName) async {
    final r = await nodeHttp.post(
      Uri.parse('$_base/admin/devices'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': phoneName}),
    );
    if (r.statusCode != 200) {
      throw Exception('Could not create a pairing token (HTTP ${r.statusCode}). Is the node running?');
    }
    final m = jsonDecode(r.body) as Map;
    final prefs = await SharedPreferences.getInstance();
    final presence = NodePresenceService.instance;
    final tunnel = presence.lastPublicUrl ?? prefs.getString('public_url') ?? '';
    final lan = await NodePresenceService.lanUrl();
    final q = <String, String>{
      'v': '1',
      'n': presence.deviceId ?? prefs.getString('desktop_device_id') ?? '',
      't': m['token'].toString(),
      if (tunnel.startsWith('http')) 'u': tunnel,
      'l': lan,
      'name': 'My PC',
    };
    final link = Uri(scheme: 'guptik', host: 'pair', queryParameters: q).toString();
    return (link: link, deviceId: m['id'].toString());
  }

  static Future<List<PairedDevice>> list() async {
    final r = await nodeHttp.get(Uri.parse('$_base/admin/devices'));
    if (r.statusCode != 200) throw Exception('HTTP ${r.statusCode}');
    final m = jsonDecode(r.body) as Map;
    return [
      for (final d in (m['devices'] as List))
        PairedDevice(
          id: d['id'].toString(),
          name: d['name'].toString(),
          lastSeen: d['last_seen_at'] == null ? null : DateTime.tryParse(d['last_seen_at'].toString())?.toLocal(),
          revoked: d['revoked_at'] != null,
        )
    ];
  }

  static Future<bool> revoke(String id) async {
    final r = await nodeHttp.delete(Uri.parse('$_base/admin/devices/${Uri.encodeComponent(id)}'));
    return r.statusCode == 200;
  }
}
