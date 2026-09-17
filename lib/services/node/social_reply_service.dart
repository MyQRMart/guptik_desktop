import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class SocialReplyService {
  static const _base = 'http://localhost:55000';

  Future<Map<String, dynamic>> settings() async {
    final res = await http.get(Uri.parse('$_base/api/social-ai')).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) return {'use_local': false};
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<void> setUseLocal(bool on) async {
    final res = await http.post(
      Uri.parse('$_base/api/social-ai'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'use_local': on}),
    ).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) throw StateError('Could not save AI toggle.');
  }

  Future<String?> draft({
    required String platform,
    required String kind,
    required String text,
    String extraPrompt = '',
  }) async {
    final res = await http.post(
      Uri.parse('$_base/api/social-reply'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'platform': platform,
        'kind': kind,
        'text': text,
        'extra_prompt': extraPrompt,
      }),
    ).timeout(const Duration(seconds: 50));
    if (res.statusCode != 200) {
      debugPrint('social-reply ${res.statusCode} ${res.body}');
      throw StateError('Local model failed (${res.statusCode}).');
    }
    final data = jsonDecode(res.body) as Map;
    if (data['ok'] != true) {
      if (data['reason'] == 'hosted') return null;
      throw StateError(data['error']?.toString() ?? 'Local model off or failed.');
    }
    final out = data['text']?.toString().trim() ?? '';
    return out.isEmpty ? null : out;
  }
}
