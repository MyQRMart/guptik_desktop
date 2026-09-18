import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:guptik_desktop/services/admin/admin_shim.dart';
import '../../services/node/node_presence_service.dart';

class DashboardOverview extends StatefulWidget {
  const DashboardOverview({super.key});

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> {
  List<Map<String, dynamic>> _devices = [];
  String _lan = '';
  String _email = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    _email = user?.email ?? '';
    _lan = await NodePresenceService.lanUrl();
    try {
      if (user != null) {
        final rows = await Supabase.instance.client
            .from('desktop_devices')
            .select('device_id, device_model, status, public_url, last_active_at')
            .eq('user_id', user.id)
            .order('last_active_at', ascending: false);
        _devices = List<Map<String, dynamic>>.from(rows as List);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Connections', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 8),
        Text(_email.isEmpty ? 'Not signed in' : 'Account: $_email', style: const TextStyle(color: Colors.white54)),
        const SizedBox(height: 4),
        Text('This PC LAN: $_lan', style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
        const SizedBox(height: 12),
        if (_loading)
          const LinearProgressIndicator(color: Colors.cyanAccent)
        else if (_devices.isEmpty)
          const ListTile(
            leading: Icon(LucideIcons.link, color: Colors.orangeAccent),
            title: Text('No devices published yet', style: TextStyle(color: Colors.white70)),
            subtitle: Text('Sign in on this PC — mobile with the same email can connect.', style: TextStyle(color: Colors.white38)),
          )
        else
          ..._devices.map((d) {
            final online = (d['status'] ?? '') == 'online';
            return Card(
              color: const Color(0xFF1E293B),
              child: ListTile(
                leading: Icon(LucideIcons.monitor, color: online ? Colors.greenAccent : Colors.white38),
                title: Text(d['device_model']?.toString() ?? 'Desktop', style: const TextStyle(color: Colors.white)),
                subtitle: Text(
                  '${d['status'] ?? 'unknown'}  ·  ${d['public_url'] ?? 'no url'}\n${d['last_active_at'] ?? ''}',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
                isThreeLine: true,
              ),
            );
          }),
      ],
    );
  }
}
