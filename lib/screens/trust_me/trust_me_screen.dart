import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TrustMeScreen extends StatefulWidget {
  const TrustMeScreen({super.key});

  @override
  State<TrustMeScreen> createState() => _TrustMeScreenState();
}

class _TrustMeScreenState extends State<TrustMeScreen> {
  final String _inviteCode = "TM-8X92-LZ"; // Mock code
  final int _timeLeft = 30;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          // Left Panel: Active Connections
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("ACTIVE TRUST CHANNELS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    itemCount: 3,
                    itemBuilder: (context, index) {
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(backgroundColor: Colors.cyanAccent, child: Icon(Icons.person, color: Colors.black)),
                        title: Text("User_Secure_${index + 1}"),
                        subtitle: const Text("Status: Connected (E2EE)", style: TextStyle(color: Colors.green)),
                        trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () {}),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const VerticalDivider(width: 40, color: Colors.grey),

          // Right Panel: New Connection Logic
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
                      QrImageView(
                        data: _inviteCode,
                        version: QrVersions.auto,
                        size: 200.0,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 20),
                      Text("Code: $_inviteCode", style: const TextStyle(fontSize: 24, letterSpacing: 4, fontFamily: 'Courier')),
                      const SizedBox(height: 10),
                      Text("Expires in $_timeLeft s", style: const TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    // Logic to regenerate code
                  },
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