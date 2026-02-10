import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../vault/vault_screen.dart';
import '../trust_me/trust_me_screen.dart';
import '../whatsapp/whatsapp_screen.dart';
import '../home_control/home_control_screen.dart';
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
    Center(child: Text("Guptik AI UI")), // Placeholder
    Center(child: Text("Security UI")), // Placeholder
  ];

  final List<String> _screenLabels = [
    'Home Control',
    'WhatsApp',
    'Vault',
    'Trust Me',
    'Guptik AI',
    'Security',
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Text(
                    "NEXUS SERVER",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: Colors.cyanAccent,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                ...List.generate(
                  _screenLabels.length,
                  (index) => _buildNavItem(index, _screenLabels[index], _screenIcons[index]),
                ),
                const Spacer(),
                // Settings at bottom
                _buildNavItem(
                  -1,
                  "Settings",
                  LucideIcons.settings,
                  isSettings: true,
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

  Widget _buildNavItem(int index, String title, IconData icon, {bool isSettings = false}) {
    bool isSelected = _selectedIndex == index;
    return ListTile(
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
      tileColor: isSelected ? Colors.white.withOpacity(0.05) : null,
      onTap: () {
        if (!isSettings) {
          setState(() => _selectedIndex = index);
        }
      },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}