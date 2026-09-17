import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../external/docker_service.dart';
import 'guptik_version.dart';

class AppRelease {
  final String tag;
  final String url;
  AppRelease({required this.tag, required this.url});
}

class UpdateService {
  UpdateService._();
  static final UpdateService instance = UpdateService._();

  static String nestNodeDir(String selected) {
    var p = selected.trim();
    while (p.endsWith('/') || p.endsWith('\\')) {
      p = p.substring(0, p.length - 1);
    }
    final name = p.split(RegExp(r'[/\\]')).last;
    if (name == 'GupTik') return p;
    if (File('$p/docker-compose.yml').existsSync()) return p;
    if (File('$p/GupTik/docker-compose.yml').existsSync()) return '$p/GupTik';
    return '$p${Platform.pathSeparator}GupTik';
  }

  static String? installedNodeVersion(String vault) {
    try {
      final f = File('$vault/.node-version');
      if (!f.existsSync()) return null;
      return f.readAsStringSync().trim();
    } catch (_) {
      return null;
    }
  }

  static bool nodeNeedsUpdate(String vault) {
    return GuptikVersion.nodeNewerThan(installedNodeVersion(vault));
  }

  Future<AppRelease?> latestDesktopRelease() async {
    try {
      final res = await http
          .get(
            Uri.parse('https://api.github.com/repos/${GuptikVersion.githubRepo}/releases/latest'),
            headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'GupTik-Desktop'},
          )
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final tag = (j['tag_name'] ?? '').toString().replaceFirst(RegExp(r'^v'), '');
      final url = (j['html_url'] ?? '').toString();
      if (tag.isEmpty) return null;
      return AppRelease(tag: tag, url: url);
    } catch (e) {
      debugPrint('latestDesktopRelease: $e');
      return null;
    }
  }
}
