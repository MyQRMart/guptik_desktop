import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guptik_desktop/services/admin/admin_shim.dart';
import '../../services/external/docker_service.dart';
import '../../services/updates/guptik_version.dart';
import '../../services/updates/update_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/login_signup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isKilling = false;
  bool _updatingNode = false;
  String? _nodeInstalled;
  String? _remoteApp;
  String? _remoteAppUrl;
  String _vaultHint = '';

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
    final existing = await DockerService.findExistingStack();
    final vault = existing?.workingDir;
    final rel = await UpdateService.instance.latestDesktopRelease();
    if (!mounted) return;
    setState(() {
      _vaultHint = vault ?? '';
      _nodeInstalled = vault == null ? null : UpdateService.installedNodeVersion(vault);
      _remoteApp = rel?.tag;
      _remoteAppUrl = rel?.url;
    });
  }

  Future<void> _applyNode() async {
    setState(() => _updatingNode = true);
    try {
      await DockerService().applyNodeUpdate();
      await _loadVersions();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Node updated. Postgres and vault files kept.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Node update failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _updatingNode = false);
    }
  }

  Future<void> _activateKillSwitch() async {
    // Confirm before killing
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("EMERGENCY KILL", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          "This will immediately shut down all local AI, Database, and Tunnel containers, terminating the session. Proceed?",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text("SHUT DOWN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isKilling = true);

    try {
      // 1. Stop all Docker Containers
      await DockerService().stopStack();

      // 2. Clear Session Info
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // 3. Sign out of Supabase
      await Supabase.instance.client.auth.signOut();

      // 4. Return to Login
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
MaterialPageRoute(builder: (_) => const LoginSignupScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
        setState(() => _isKilling = false);
      }
    }
  }

  Widget _updatesCard() {
    final nodeStale = GuptikVersion.nodeNewerThan(_nodeInstalled);
    final appStale = _remoteApp != null && GuptikVersion.appNewer(_remoteApp!);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF252526),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2B2B2B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Updates', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Desktop app and node update separately. Node updates do not reinstall the app.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 11)),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.desktop_windows, size: 16, color: Color(0xFF00E5FF)),
            title: Text('Desktop app  ${GuptikVersion.app}', style: const TextStyle(fontSize: 12)),
            subtitle: Text(
              appStale ? 'Newer: $_remoteApp' : (_remoteApp == null ? 'This build' : 'Up to date'),
              style: const TextStyle(fontSize: 11),
            ),
            trailing: appStale && _remoteAppUrl != null
                ? TextButton(
                    onPressed: () => launchUrl(Uri.parse(_remoteAppUrl!)),
                    child: const Text('Open', style: TextStyle(fontSize: 12)),
                  )
                : null,
          ),
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.dns, size: 16, color: Color(0xFF00E5FF)),
            title: Text('Node  ${GuptikVersion.node}', style: const TextStyle(fontSize: 12)),
            subtitle: Text(
              'Installed: ${_nodeInstalled ?? "unknown"}${_vaultHint.isEmpty ? "" : "\n$_vaultHint"}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: TextButton(
              onPressed: (_updatingNode || !nodeStale) ? null : _applyNode,
              child: _updatingNode
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(nodeStale ? 'Update node' : 'Current', style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
          const SizedBox(height: 16),
          _updatesCard(),
          const SizedBox(height: 16),

          // Regular Settings Panel
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
            ),
            child: const Column(
              children: [
                ListTile(
                  leading: Icon(Icons.person, color: Colors.cyanAccent),
                  title: Text("Account Details"),
                  subtitle: Text("Manage your connected user profile"),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey),
                ),
                Divider(color: Colors.white10),
                ListTile(
                  leading: Icon(Icons.data_usage, color: Colors.cyanAccent),
                  title: Text("Storage Location"),
                  subtitle: Text("View current vault and database path"),
                  trailing: Icon(Icons.chevron_right, color: Colors.grey),
                ),
              ],
            ),
          ),

          const Spacer(),

          // KILL SWITCH PANEL
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(Icons.power_settings_new, color: Colors.redAccent, size: 32),
                ),
                const SizedBox(width: 20),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("SYSTEM KILL SWITCH", style: TextStyle(color: Colors.redAccent, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      SizedBox(height: 4),
                      Text("Instantly shuts down all background services, destroys the tunnel connection, and logs you out.", 
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                SizedBox(
                  width: 150,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isKilling ? null : _activateKillSwitch,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                    child: _isKilling
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("ACTIVATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}