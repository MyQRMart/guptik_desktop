import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("VAULT STORAGE", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: () {}, // Trigger Sync Logic
                icon: const Icon(LucideIcons.refreshCw),
                label: const Text("SYNC NOW"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyanAccent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Storage Stats
          Row(
            children: [
              _buildStatCard("Total Files", "1,240"),
              const SizedBox(width: 16),
              _buildStatCard("Storage Used", "450 GB"),
              const SizedBox(width: 16),
              _buildStatCard("Encrypted", "YES", color: Colors.greenAccent),
            ],
          ),
          const SizedBox(height: 30),

          // File Grid
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                childAspectRatio: 1.0,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: 10, // Mock count
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.fileImage, size: 48, color: Colors.blueGrey),
                      const SizedBox(height: 12),
                      Text("IMG_2026_$index.jpg", style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: 180,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(color: color ?? Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}