import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../vault/vault_screen.dart';
import '../trust_me/trust_me_screen.dart';
import '../whatsapp/whatsapp_screen.dart';
import '../home_control/home_control_screen.dart';
import '../auth/qr_login_screen.dart'; // Make sure this path is correct
import '../../widgets/window_header.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0; // Default to Home Control

  // Feature Views
  final List<Widget> _screens = const [
    HomeControlScreen(),
    WhatsAppScreen(),
    VaultScreen(),
    TrustMeScreen(),
    Center(child: Text("Guptik AI UI", style: TextStyle(color: Colors.white))), 
    Center(child: Text("Security UI", style: TextStyle(color: Colors.white))), 
    SettingsScreen(), // Added Settings Screen at Index 6
  ];

  final List<String> _screenLabels = [
    'Home Control',
    'WhatsApp',
    'Vault',
    'Trust Me',
    'Guptik AI',
    'Security',
    'Settings', // Added label
  ];

  final List<IconData> _screenIcons = [
    LucideIcons.home,
    LucideIcons.messageCircle,
    LucideIcons.database,
    LucideIcons.shieldCheck,
    LucideIcons.bot,
    LucideIcons.lock,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: WindowHeader(title: _screenLabels[_selectedIndex]),
      ),
      body: Row(
        children: [
          // SIDEBAR
          Container(
            width: 250,
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              border: Border(right: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "NEXUS SERVER",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.cyanAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                ...List.generate(
                  _screenIcons.length,
                  (index) => _buildNavItem(index, _screenLabels[index], _screenIcons[index]),
                ),
                const Spacer(),
                // Settings at bottom (Routes to Index 6)
                _buildNavItem(
                  6,
                  "Settings",
                  LucideIcons.settings,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          // MAIN CONTENT AREA
          Expanded(
            child: Container(
              color: const Color(0xFF0F172A),
              child: _screens[_selectedIndex],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon) {
    bool isSelected = _selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.cyanAccent : Colors.grey,
          size: 20,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 14,
          ),
        ),
        tileColor: isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent,
        onTap: () {
          setState(() => _selectedIndex = index);
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}

// ==========================================
// INTERNAL SETTINGS & KILL SWITCH SCREEN
// ==========================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _deviceData;
  bool _isLoading = true;
  String _localDeviceId = "Unknown";

  @override
  void initState() {
    super.initState();
    _fetchDeviceData();
  }

  Future<void> _fetchDeviceData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceId = prefs.getString('device_id');
      
      if (deviceId != null) {
        _localDeviceId = deviceId;
        // Fetch from Admin Supabase
        final response = await Supabase.instance.client
            .from('desktop_devices')
            .select()
            .eq('device_id', deviceId)
            .maybeSingle();

        if (mounted) {
          setState(() {
            _deviceData = response;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching settings: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // THE KILL SWITCH: Clears internal app data forcefully
  Future<void> _factoryReset() async {
    // 1. Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    // 2. (Optional) Set device to unverified in Admin Supabase
    if (_deviceData != null) {
      try {
        await Supabase.instance.client
            .from('desktop_devices')
            .update({'is_verified': false, 'installation_status': 'disconnected'})
            .eq('device_id', _localDeviceId);
      } catch (_) {}
    }

    // 3. Kick user back to QR Login Screen and destroy navigation stack
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const QrLoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
    }

    return Padding(
      padding: const EdgeInsets.all(40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SYSTEM SETTINGS", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 30),
          
          // ADMIN SUPABASE DATA DISPLAY
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Admin Cloud Connection (desktop_devices table)", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                const Divider(color: Colors.white10, height: 30),
                _buildInfoRow("Local Device ID (SharedPrefs)", _localDeviceId),
                _buildInfoRow("Database ID", _deviceData?['id'] ?? "Not Found"),
                _buildInfoRow("Model", _deviceData?['device_model'] ?? "N/A"),
                _buildInfoRow("Vault Path", _deviceData?['vault_path'] ?? "Not Configured"),
                _buildInfoRow("Public URL (Cloudflare)", _deviceData?['public_url'] ?? "Pending"),
                _buildInfoRow("Status", _deviceData?['installation_status'] ?? "Unknown"),
                _buildInfoRow("Verified", _deviceData?['is_verified']?.toString() ?? "False"),
              ],
            ),
          ),

          const Spacer(),

          // FACTORY RESET BUTTON
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text("Factory Reset & Disconnect", style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 5),
                    Text("Clears internal cache, wiping the device_id and forcing QR Login.", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _factoryReset,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(LucideIcons.powerOff),
                  label: const Text("DISCONNECT"),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 250, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontFamily: 'Courier'))),
        ],
      ),
    );
  }
}