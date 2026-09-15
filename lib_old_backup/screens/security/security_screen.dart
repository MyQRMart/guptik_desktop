import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../services/external/osint_service.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final OsintService _osintService = OsintService();
  String _terminalOutput = "Awaiting target input...";
  bool _isSearching = false;

  Future<void> _executeSearch() async {
    final target = _searchController.text.trim();
    if (target.isEmpty) return;

    setState(() {
      _isSearching = true;
      _terminalOutput = "[*] Launching containerized OSINT script...\n[*] Target: $target";
    });

    final result = await _osintService.runSearch(target);

    setState(() {
      _terminalOutput = result;
      _isSearching = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(icon: Icon(LucideIcons.search), text: "OSINT Search"),
            Tab(icon: Icon(LucideIcons.smartphone), text: "Mobile Tracking"),
            Tab(icon: Icon(LucideIcons.workflow), text: "n8n Automation"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOsintSearch(),
              _buildMobileTracking(),
              _buildN8nView(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOsintSearch() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Enter Phone, IG, FB ID, or Email...",
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(LucideIcons.target, color: Colors.cyanAccent),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: _isSearching 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.cyanAccent))
                    : const Icon(LucideIcons.search, color: Colors.white),
                onPressed: _isSearching ? null : _executeSearch, // <--- TRIGGER SEARCH
              ),
            ),
            onSubmitted: (_) => _isSearching ? null : _executeSearch(),
          ),
          const SizedBox(height: 20),
          const Text("TERMINAL OUTPUT", style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _terminalOutput,
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontFamily: 'Courier',
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMobileTracking() {
    return const Center(
      child: Text(
        "Call and SMS Logs from User Postgres",
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildN8nView() {
    // Requires desktop webview implementation to load localhost:5678
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          "n8n Web Interface Embed (localhost:5678)",
          style: TextStyle(color: Colors.cyanAccent),
        ),
      ),
    );
  }
}