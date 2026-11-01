import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/external/docker_service.dart';
import '../../services/node/node_pairing.dart';

/// Settings card: pair a phone with this node (QR), list/revoke paired phones,
/// and switch the gateway between audit and enforce mode.
class PairPhoneCard extends StatefulWidget {
  const PairPhoneCard({super.key});
  @override
  State<PairPhoneCard> createState() => _PairPhoneCardState();
}

class _PairPhoneCardState extends State<PairPhoneCard> {
  List<PairedDevice> _devices = [];
  String? _error;
  String _mode = 'audit';
  bool _busy = false;
  String? _link;
  int _secondsLeft = 0;
  Timer? _timer;
  final _name = TextEditingController(text: 'My phone');

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _name.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final d = await NodePairing.list();
      final m = await DockerService().gatewayAuthMode();
      if (mounted) setState(() { _devices = d; _mode = m; _error = null; });
    } catch (e) {
      if (mounted) setState(() => _error = 'Node not reachable yet: $e');
    }
  }

  Future<void> _pair() async {
    setState(() { _busy = true; _error = null; });
    try {
      final r = await NodePairing.mintLink(_name.text.trim().isEmpty ? 'Phone' : _name.text.trim());
      _timer?.cancel();
      setState(() { _link = r.link; _secondsLeft = 120; });
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return t.cancel();
        if (_secondsLeft <= 1) {
          t.cancel();
          setState(() => _link = null); // hide the QR; the token stays valid until revoked
          _refresh();
        } else {
          setState(() => _secondsLeft--);
        }
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setMode(bool enforce) async {
    setState(() => _busy = true);
    try {
      await DockerService().setGatewayAuthMode(enforce: enforce);
      await _refresh();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.phonelink_lock, color: Colors.cyanAccent),
            SizedBox(width: 10),
            Text('Phone pairing & node security', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 8),
          const Text(
            'Pair your phone so only your devices can write to your node. Unpaired phones can still watch public videos.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (_link == null)
            Row(children: [
              SizedBox(
                width: 200,
                child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Phone name', isDense: true)),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _busy ? null : _pair,
                icon: const Icon(Icons.qr_code_2),
                label: const Text('Pair a phone'),
              ),
            ])
          else
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(data: _link!, size: 220),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Scan this in GupTik on your phone (Settings → Pair with PC).'),
                  const SizedBox(height: 6),
                  Text('Hides in $_secondsLeft s. Do not share or screenshot it: it grants access to your node.',
                      style: const TextStyle(color: Colors.amber)),
                  TextButton(onPressed: () => setState(() => _link = null), child: const Text('Hide now')),
                ]),
              ),
            ]),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
          const Divider(color: Colors.white10, height: 28),
          const Text('Paired phones', style: TextStyle(fontWeight: FontWeight.w600)),
          if (_devices.where((d) => !d.revoked).isEmpty)
            const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Text('None yet.', style: TextStyle(color: Colors.grey))),
          for (final d in _devices.where((d) => !d.revoked))
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.smartphone, color: Colors.cyanAccent),
              title: Text(d.name),
              subtitle: Text(d.lastSeen == null ? 'Not used yet' : 'Last seen ${d.lastSeen}'),
              trailing: TextButton(
                onPressed: () async {
                  await NodePairing.revoke(d.id);
                  _refresh();
                },
                child: const Text('Revoke', style: TextStyle(color: Colors.redAccent)),
              ),
            ),
          const Divider(color: Colors.white10, height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Require pairing (enforce)'),
            subtitle: Text(
              _mode == 'enforce'
                  ? 'ON: requests without a valid token are blocked.'
                  : 'OFF (audit): nothing is blocked yet; the gateway logs what would be. Pair your phones, then turn this on.',
              style: const TextStyle(color: Colors.grey),
            ),
            value: _mode == 'enforce',
            onChanged: _busy ? null : _setMode,
          ),
        ],
      ),
    );
  }
}
