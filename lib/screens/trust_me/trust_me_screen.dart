import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/external/postgres_service.dart';
import 'package:flutter/services.dart';
import '../../services/supabase_service.dart';


class TrustMeScreen extends StatefulWidget {
  const TrustMeScreen({super.key});

  @override
  State<TrustMeScreen> createState() => _TrustMeScreenState();
}

class _TrustMeScreenState extends State<TrustMeScreen> {
  final PostgresService _db = PostgresService();
  List<Map<String, dynamic>> _channels = [];
  String _inviteCode = "";
  bool _isLoading = true;
  String get _formattedLink {
    final reversedUid = SupabaseService().reversedUserId;
    return "https://$reversedUid-guptik.myqrmart.com/handshake?code=$_inviteCode";
  }

  @override
  void initState() {
    super.initState();
    _loadChannels();
    _generateNewCode();
  }

  Future<void> _loadChannels() async {
    final data = await _db.getTrustChannels();
    setState(() {
      _channels = data;
      _isLoading = false;
    });
  }

  void _generateNewCode() {
    setState(() {
      // Logic for generating a unique 8-character code
      _inviteCode = "TM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
    });
  }

  Future<void> _deleteChannel(String id) async {
    await _db.deleteTrustChannel(id);
    _loadChannels();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("ACTIVE TRUST CHANNELS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Expanded(
                  child: _isLoading 
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _channels.length,
                        itemBuilder: (context, index) {
                          final channel = _channels[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const CircleAvatar(backgroundColor: Colors.cyanAccent, child: Icon(Icons.person, color: Colors.black)),
                            title: Text(channel['user_name'] ?? "Unknown User"),
                            subtitle: const Text("Status: Connected (E2EE)", style: TextStyle(color: Colors.green)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red), 
                              onPressed: () => _deleteChannel(channel['id'].toString()),
                            ),
                          );
                        },
                      ),
                ),
              ],
            ),
          ),
          
          const VerticalDivider(width: 40, color: Colors.grey),

          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.cyanAccent.withOpacity(0.5)),
                  ),
                  child: Column(
                    children: [
                      const Text("NEW CONNECTION", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
                      const SizedBox(height: 20),
                      if (_inviteCode.isNotEmpty)
                        QrImageView(
                          data: _formattedLink, // Updated to use the full link for QR as well
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                        ),
                      const SizedBox(height: 20),
                      Text("Code: $_inviteCode", style: const TextStyle(fontSize: 24, letterSpacing: 4, fontFamily: 'Courier')),
                      const SizedBox(height: 20),
                      const Text("SHARE CONNECTION LINK", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: SelectableText(_formattedLink, style: const TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy, size: 16),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: _formattedLink));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Link copied to clipboard")),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _generateNewCode,
                  child: const Text("GENERATE NEW LINK"),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}