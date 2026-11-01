import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../external/db_secrets.dart';

/// The desktop's owner token for its own node's gateway (`gt1.owner.<secret>`).
/// The plaintext lives in the OS secure storage; only SHA-256(secret) is written to
/// `<vault>/.env` as OWNER_TOKEN_SHA256 for the gateway to compare against.
class NodeSecrets {
  NodeSecrets._();

  static const _key = 'owner_token_v1';
  static const _storage = FlutterSecureStorage();
  static String? _cached;

  static String hashSecret(String secret) => sha256.convert(utf8.encode(secret)).toString();

  /// Owner token already loaded in memory (null before the node has been opened).
  static String? get cachedOwnerToken => _cached;

  static String _secretOf(String token) => token.split('.').last;

  // Some Linux desktops have no keyring; fall back to an owner-only file in the config dir.
  static File get _fallbackFile =>
      File('${Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.'}/.config/guptik/owner_token');

  static Future<String?> _read() async {
    try {
      final v = await _storage.read(key: _key);
      if (v != null && v.isNotEmpty) return v;
    } catch (_) {}
    try {
      if (await _fallbackFile.exists()) return (await _fallbackFile.readAsString()).trim();
    } catch (_) {}
    return null;
  }

  static Future<void> _write(String token) async {
    try {
      await _storage.write(key: _key, value: token);
      final probe = await _storage.read(key: _key);
      if (probe == token) return;
    } catch (_) {}
    final f = _fallbackFile;
    await f.parent.create(recursive: true);
    await f.writeAsString(token, flush: true);
    if (!Platform.isWindows) await Process.run('chmod', ['600', f.path]);
  }

  /// Loads (or creates) the owner token and makes sure [env] (the vault's .env map) carries its hash,
  /// a GATEWAY_AUTH mode and a viewer signing key. Returns true when [env] was changed.
  static Future<bool> ensureOwnerToken(Map<String, String> env) async {
    var token = await _read();
    if (token == null || !token.startsWith('gt1.owner.')) {
      token = 'gt1.owner.${DbSecrets.generate(32)}';
      await _write(token);
    }
    _cached = token;
    var changed = false;
    final h = hashSecret(_secretOf(token));
    if (env['OWNER_TOKEN_SHA256'] != h) {
      env['OWNER_TOKEN_SHA256'] = h;
      changed = true;
    }
    if (!env.containsKey('GATEWAY_AUTH')) {
      env['GATEWAY_AUTH'] = 'audit';
      changed = true;
    }
    if ((env['VIEWER_SIGNING_KEY'] ?? '').length < 16) {
      env['VIEWER_SIGNING_KEY'] = DbSecrets.generate(32);
      changed = true;
    }
    return changed;
  }

  /// Loads the owner token into memory without touching .env.
  static Future<String?> load() async {
    final t = await _read();
    if (t != null && t.startsWith('gt1.owner.')) _cached = t;
    return _cached;
  }
}
