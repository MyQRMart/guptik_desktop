import 'dart:collection';
import 'dart:io';
import 'dart:math';

/// Database credentials for this node. They live only in `<vault>/.env`
/// (owner-readable) and in memory; they are generated per install and are not
/// derived from the account password.
///
///   DB_PASSWORD        Postgres superuser (`postgres`): gateway + desktop services
///   DB_USER_PASSWORD   the per-account login role the desktop app uses
///   DB_SECRET_VERSION  `2` once this node has been moved off the old shared password
class DbSecrets {
  DbSecrets._();

  static const currentVersion = '2';
  static String? _master;
  static String? _user;

  static bool get isLoaded => _master != null && _user != null;

  /// Postgres superuser password. Throws if the node has not been opened yet.
  static String get master =>
      _master ?? (throw StateError('Database secrets are not loaded. Open the node first.'));

  /// Password of the per-account Postgres role.
  static String get user =>
      _user ?? (throw StateError('Database secrets are not loaded. Open the node first.'));

  static void set({required String master, required String user}) {
    _master = master;
    _user = user;
  }

  static void clear() {
    _master = null;
    _user = null;
  }

  /// Random hex secret (hex only, so it is safe in `.env`, compose and SQL literals).
  static String generate([int bytes = 24]) {
    final r = Random.secure();
    return List.generate(bytes, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  static File envFile(String vault) => File('$vault/.env');

  static Map<String, String> parseEnv(String text) {
    final out = LinkedHashMap<String, String>();
    for (final raw in text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final i = line.indexOf('=');
      if (i <= 0) continue;
      out[line.substring(0, i).trim()] = line.substring(i + 1).trim();
    }
    return out;
  }

  static Map<String, String> readEnvSync(String vault) {
    final f = envFile(vault);
    return f.existsSync() ? parseEnv(f.readAsStringSync()) : LinkedHashMap<String, String>();
  }

  /// Writes the whole env map (temp file + rename) and restricts it to the owner where the OS supports it.
  static Future<void> writeEnv(String vault, Map<String, String> env) async {
    final f = envFile(vault);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString('${env.entries.map((e) => '${e.key}=${e.value}').join('\n')}\n', flush: true);
    if (!Platform.isWindows) await Process.run('chmod', ['600', tmp.path]);
    await tmp.rename(f.path);
  }

  /// True when the node's `.env` is on the new scheme. Loads the secrets into memory in that case.
  static bool loadFrom(String vault) {
    final env = readEnvSync(vault);
    final m = env['DB_PASSWORD'], u = env['DB_USER_PASSWORD'];
    if (env['DB_SECRET_VERSION'] == currentVersion && m != null && m.isNotEmpty && u != null && u.isNotEmpty) {
      set(master: m, user: u);
      return true;
    }
    return false;
  }
}
