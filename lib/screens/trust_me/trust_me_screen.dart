import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // 🚀 Allows us to copy text to the PC's Clipboard!
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:guptik_desktop/screens/trust_me/secure_chats_screen.dart';
import 'package:guptik_desktop/services/external/postgres_service.dart';
import 'package:guptik_desktop/services/trustme/trust_crypto_service.dart';
import 'package:guptik_desktop/services/trustme/trust_me_service.dart';
import 'dart:async';

class TrustMeScreen extends StatefulWidget {
  const TrustMeScreen({super.key});

  @override
  State<TrustMeScreen> createState() => _TrustMeScreenState();
}

class _TrustMeScreenState extends State<TrustMeScreen> {
  int _selectedIndex = 0;
  bool _isGeneratingKeys = false;
  bool _isNodeReady = false;
  final _secureStorage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initializeDesktopNode();
  }

  // --- 🚀 DYNAMIC NODE INITIALIZER ---
  Future<void> _initializeDesktopNode() async {
    setState(() => _isGeneratingKeys = true);

    try {
      final db = PostgresService();

      // 1. DYNAMIC USER DATA (Read from login storage)
      final actualGuptikId =
          await _secureStorage.read(key: 'current_user_id') ?? 'unknown_id';
      final actualUsername =
          await _secureStorage.read(key: 'current_username') ?? 'unknown_user';

      // 2. Check Database
      final hasIdentity = await db.hasTrustIdentity();

      if (!hasIdentity) {
        debugPrint(
          "First time launch for $actualUsername. Booting Crypto Engine...",
        );

        // Use the proper singleton call
        final publicBundle = await TrustCryptoService()
            .generateInitialKeyBundle();

        // 3. Inject dynamic data into PostgreSQL
        await db.saveTrustIdentity(
          guptikId: actualGuptikId,
          username: actualUsername,
          keyBundle: publicBundle,
          deviceFingerprint: 'desktop_primary_node_01',
        );
      } else {
        debugPrint("Cryptographic Identity found. Node is ready.");
      }

      if (mounted) {
        setState(() {
          _isNodeReady = true;
          _isGeneratingKeys = false;
        });
      }
    } catch (e) {
      debugPrint("Fatal Node Initialization Error: $e");
      if (mounted) setState(() => _isGeneratingKeys = false);
    }
  }

  // --- 🚀 LIVE: GENERATE HANDSHAKE CODE ---
  void _showGenerateCodeDialog() async {
    // Store instances BEFORE the async gap to satisfy Flutter's context rules
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      ),
    );

    try {
      // Hit the gateway to get a fresh random code!
      final result = await TrustMeService.instance.generateHandshakeCode(
        'target_username_here',
      );

      navigator.pop(); // Close loading spinner

      if (mounted) {
        // Open our custom Smart Countdown Dialog
        showDialog(
          context: context,
          barrierDismissible: false, // Forces them to wait or hit Cancel
          builder: (context) => _CountdownCodeDialog(result: result),
        );
      }
    } catch (e) {
      navigator.pop(); // Close spinner safely
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    }
  }

  // --- 🚀 LIVE: ENTER HANDSHAKE CODE ---
  void _showEnterCodeDialog() {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text(
            "Enter Peer Code",
            style: TextStyle(color: Colors.white),
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Enter the 6-digit code provided by your contact to initiate the exchange.",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: codeController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    letterSpacing: 12,
                  ),
                  textAlign: TextAlign.center,
                  maxLength: 6,
                  decoration: InputDecoration(
                    counterText: "",
                    filled: true,
                    fillColor: Colors.black26,
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey.shade700),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.cyanAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
              ),
              onPressed: () async {
                final code = codeController.text.trim();
                if (code.length != 6) return;

                // Close the entry dialog safely using its specific context
                Navigator.pop(dialogContext);

                // Store safely before async gap
                final navigator = Navigator.of(context);
                final scaffoldMessenger = ScaffoldMessenger.of(context);

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (c) => const Center(
                    child: CircularProgressIndicator(color: Colors.cyanAccent),
                  ),
                );

                try {
                  final pending = await TrustMeService.instance
                      .getPendingRequests();
                  if (pending.isEmpty) {
                    throw Exception("No pending connection requests found.");
                  }

                  final sessionId = pending.first['handshake_session_id'];

                  final result = await TrustMeService.instance
                      .enterHandshakeCode(code: code, sessionId: sessionId);

                  navigator.pop(); // Close spinner safely

                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(result['message'] ?? "Code matched!"),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  navigator.pop(); // Close spinner safely
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text("Error: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text(
                "Verify Contact",
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isGeneratingKeys || !_isNodeReady) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.cyanAccent),
              const SizedBox(height: 24),
              const Text(
                "Initializing Cryptographic Node...",
                style: TextStyle(
                  color: Colors.cyanAccent,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Generating Ed25519 Identity and X25519 Pre-keys.\nSecuring local database...",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Row(
        children: [
          // ---------------------------------------------------
          // LEFT SIDEBAR
          // ---------------------------------------------------
          Container(
            width: 250,
            color: const Color(0xFF1E293B),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    "TRUST ME",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                _buildNavItem(Icons.dashboard_outlined, "Node Dashboard", 0),
                _buildNavItem(Icons.chat_bubble_outline, "Secure Chats", 1),
                _buildNavItem(Icons.group_outlined, "Groups", 2),
                _buildNavItem(Icons.help_outline, "Unknown Inbox", 3),
                const Spacer(),
                const Divider(color: Colors.white12, height: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(
                          Icons.qr_code,
                          color: Colors.black,
                          size: 18,
                        ),
                        label: const Text(
                          "Generate Code",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.cyanAccent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _showGenerateCodeDialog,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.keyboard,
                          color: Colors.cyanAccent,
                          size: 18,
                        ),
                        label: const Text(
                          "Enter Code",
                          style: TextStyle(color: Colors.cyanAccent),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.cyanAccent),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _showEnterCodeDialog,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ---------------------------------------------------
          // RIGHT CONTENT AREA
          // ---------------------------------------------------
          Expanded(child: _buildContentArea()),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String title, int index) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        color: isSelected
            ? Colors.white.withAlpha(12)
            : Colors.transparent, // Modern withAlpha
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.cyanAccent : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentArea() {
    switch (_selectedIndex) {
      case 0:
        return _buildNodeDashboard();
      case 1:
        return const SecureChatsScreen();
      case 2:
        return _buildEmptyState(
          Icons.group_outlined,
          "No groups managed by this node.",
        );
      case 3:
        return _buildEmptyState(Icons.help_outline, "Unknown inbox is clear.");
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildNodeDashboard() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Node Dashboard",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Manage your local P2P gateway and cryptographic identity.",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 32),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.router, color: Colors.cyanAccent),
                    SizedBox(width: 12),
                    Text(
                      "Gateway Network Status",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildStatusRow("Docker Gateway container", true),
                _buildStatusRow("PostgreSQL Database", true),
                _buildStatusRow("Cloudflare Tunnel", true),
                const Divider(color: Colors.white12, height: 32),
                const Text(
                  "Permanent Node Address:",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const SelectableText(
                      "https://your-id-guptik.myqrmart.com",
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontFamily: 'monospace',
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(
                        Icons.copy,
                        color: Colors.grey,
                        size: 18,
                      ),
                      tooltip: "Copy URL",
                      // 🚀 NEW ADDED: Fixed the empty onPressed block here!
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(
                            text: "https://your-id-guptik.myqrmart.com",
                          ),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Node Address copied!"),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, color: Colors.greenAccent),
                    SizedBox(width: 12),
                    Text(
                      "Cryptographic Identity",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 24),
                Text(
                  "Ed25519 Identity Key: GENERATED",
                  style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                ),
                SizedBox(height: 8),
                Text(
                  "X25519 Signed Pre-Key: ACTIVE (Rotates in 29 days)",
                  style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                ),
                SizedBox(height: 8),
                Text(
                  "One-Time Pre-Keys Remaining: 100/100",
                  style: TextStyle(color: Colors.grey, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String label, bool isOnline) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: isOnline ? Colors.greenAccent : Colors.redAccent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(
            isOnline ? "ONLINE" : "OFFLINE",
            style: TextStyle(
              color: isOnline ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String text) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.white10),
          const SizedBox(height: 24),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------
// SMART COUNTDOWN DIALOG WIDGET
// ---------------------------------------------------
class _CountdownCodeDialog extends StatefulWidget {
  final Map<String, dynamic> result;
  const _CountdownCodeDialog({required this.result});

  @override
  State<_CountdownCodeDialog> createState() => _CountdownCodeDialogState();
}

class _CountdownCodeDialogState extends State<_CountdownCodeDialog> {
  int _timeLeft = 30; // Starts at 30 seconds
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Start the countdown timer!
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() => _timeLeft--); // Reduce time by 1
      } else {
        // Time is up! Cancel the timer and auto-close the dialog
        timer.cancel();
        if (mounted) Navigator.of(context).pop();
      }
    });
  }

  @override
  void dispose() {
    _timer
        ?.cancel(); // Always clean up the timer if the user closes it manually
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: const Text(
        "Generate Handshake Code",
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Share this secure code out-of-band.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.cyanAccent.withAlpha(128)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  SelectableText(
                    widget.result['code'] ?? '------',
                    style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 36,
                      letterSpacing: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // The Code Copy Button
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.cyanAccent),
                    tooltip: "Copy Code",
                    onPressed: () async {
                      // Grabs the code and writes it to the PC's Clipboard
                      final code = widget.result['code'] ?? '';
                      await Clipboard.setData(ClipboardData(text: code));

                      // Shows a quick green success message
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Code copied to clipboard!"),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // THE LIVE COUNTDOWN UI
            CircularProgressIndicator(
              value: _timeLeft / 30, // Spinner shrinks as time runs out!
              color: _timeLeft > 10 ? Colors.cyanAccent : Colors.redAccent,
              backgroundColor: Colors.white12,
            ),
            const SizedBox(height: 16),
            Text(
              "Code expires in $_timeLeft seconds...",
              style: TextStyle(
                color: _timeLeft > 10 ? Colors.orangeAccent : Colors.redAccent,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
