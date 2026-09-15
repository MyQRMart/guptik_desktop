import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:lucide_icons/lucide_icons.dart';

class N8nWebviewScreen extends StatefulWidget {
  const N8nWebviewScreen({super.key});

  @override
  State<N8nWebviewScreen> createState() => _N8nWebviewScreenState();
}

class _N8nWebviewScreenState extends State<N8nWebviewScreen> {
  final _controller = WebviewController();
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _initWebview();
  }

  Future<void> _initWebview() async {
    await _controller.initialize();

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email') ?? '';

      // 1. Authenticate via n8n's backend API
      final response = await http.post(
        Uri.parse('http://localhost:56887/rest/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"email": email, "password": 'Gupt1k_pa55'}),
      );

      // 2. Extract the auth cookie
      final setCookie = response.headers['set-cookie'];
      if (setCookie != null && setCookie.contains('n8n-auth=')) {
        final authCookie = setCookie.split('n8n-auth=')[1].split(';')[0];
        
        // 3. Load a blank health endpoint just to get on the localhost domain
        await _controller.loadUrl('http://localhost:56887/healthz');
        await Future.delayed(const Duration(milliseconds: 500)); 
        
        // 4. Inject the cookie via Javascript!
        await _controller.executeScript('document.cookie = "n8n-auth=$authCookie; path=/";');
      }
    } catch (e) {
      debugPrint("Auto-login script error: $e");
    }

    // 5. Load the actual dashboard. It will bypass the login screen entirely.
    await _controller.loadUrl('http://localhost:56887/workflow');
    
    if (!mounted) return;
    setState(() => _isReady = true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Guptik Automations", style: TextStyle(color: Colors.cyanAccent, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isReady 
        ? Webview(_controller)
        : const Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          ),
    );
  }
}