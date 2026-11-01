import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:guptik_desktop/services/external/db_secrets.dart';

void main() {
  test('generate is hex and unique', () {
    final a = DbSecrets.generate(), b = DbSecrets.generate();
    expect(a, matches(RegExp(r'^[0-9a-f]{48}$')));
    expect(a, isNot(b));
  });

  test('env round trip keeps unknown keys and only v2 loads', () async {
    final d = await Directory.systemTemp.createTemp('envtest');
    addTearDown(() => d.delete(recursive: true));
    // legacy file: POSTGRES_PASSWORD there is the account password and must not be trusted
    await File('${d.path}/.env').writeAsString('POSTGRES_PASSWORD=x\nPOSTGRES_PORT=55432\nPUBLIC_URL=a.b\n');
    DbSecrets.clear();
    expect(DbSecrets.loadFrom(d.path), isFalse);
    expect(DbSecrets.isLoaded, isFalse);

    final env = DbSecrets.readEnvSync(d.path)
      ..remove('POSTGRES_PASSWORD')
      ..['DB_PASSWORD'] = 'm' * 8
      ..['DB_USER_PASSWORD'] = 'u' * 8
      ..['DB_SECRET_VERSION'] = DbSecrets.currentVersion;
    await DbSecrets.writeEnv(d.path, env);
    final text = await File('${d.path}/.env').readAsString();
    expect(text, contains('PUBLIC_URL=a.b'));
    expect(text, isNot(contains('POSTGRES_PASSWORD')));
    expect(DbSecrets.loadFrom(d.path), isTrue);
    expect(DbSecrets.master, 'mmmmmmmm');
    expect(DbSecrets.user, 'uuuuuuuu');
    DbSecrets.clear();
    expect(() => DbSecrets.master, throwsStateError);
  });
}
