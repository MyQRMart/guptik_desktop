import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart'; // <--- ADD THIS IMPORT

class AutomationScreen extends StatelessWidget {
  const AutomationScreen({super.key});

  // Launch n8n locally
  Future<void> _launchN8n() async {
    final Uri url = Uri.parse('http://localhost:56887');
    if (!await launchUrl(url)) {
      debugPrint('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.workflow, size: 80, color: Colors.cyanAccent),
          const SizedBox(height: 20),
          const Text(
            "Guptik Automations",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "Powered by local n8n. Workflows are isolated and secure.",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _launchN8n, // <--- UPDATED ACTION
            icon: const Icon(LucideIcons.externalLink, color: Color(0xFF0F172A)),
            label: const Text(
              "Build Your Automations",
              style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyanAccent,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}