import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../vault/vault_screen.dart';
import '../trust_me/trust_me_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 1; // Default to Vault for now

  // Feature Views
  final List<Widget> _screens = [
    const Center(child: Text("Home Control UI")), // Placeholder
    const VaultScreen(),
    const TrustMeScreen(),
    const Center(child: Text("Guptik UI")), // Placeholder
    const Center(child: Text("Security UI")), // Placeholder
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  child: Text("NEXUS SERVER", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.cyanAccent)),
                ),
                const SizedBox(height: 40),
                _buildNavItem(0, "Home Control", LucideIcons.home),
                _buildNavItem(1, "Vault", LucideIcons.database),
                _buildNavItem(2, "Trust Me", LucideIcons.shieldCheck),
                _buildNavItem(3, "Guptik AI", LucideIcons.bot),
                _buildNavItem(4, "Security", LucideIcons.lock),
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
    return ListTile(
      leading: Icon(icon, color: isSelected ? Colors.cyanAccent : Colors.grey),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.grey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      tileColor: isSelected ? Colors.white.withOpacity(0.05) : null,
      onTap: () => setState(() => _selectedIndex = index),
    );
  }
}