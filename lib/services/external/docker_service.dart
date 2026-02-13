import 'dart:io';
import 'package:process_run/shell.dart';

class DockerService {
  final Shell _shell = Shell();
  String? _vaultPath;

  // Fixes: "The method 'setVaultPath' isn't defined"
  void setVaultPath(String path) => _vaultPath = path;

  // Fixes: "The method 'autoConfigure' isn't defined"
  // This automatically generates the files so the user doesn't have to
  Future<void> autoConfigure({
    required String dbPass,
    required String tunnelToken,
    required String publicUrl,
    String port = "5432",
  }) async {
    if (_vaultPath == null) throw Exception("Vault path not set");

    // 1. Generate .env
    final envFile = File('$_vaultPath/.env');
    await envFile.writeAsString('''
POSTGRES_PORT=$port
POSTGRES_PASSWORD=$dbPass
CF_TUNNEL_TOKEN=$tunnelToken
VAULT_PATH=$_vaultPath
PUBLIC_URL=$publicUrl
''');

    // 2. Generate kong.yml for routing
    final kongFile = File('$_vaultPath/kong.yml');
    await kongFile.writeAsString('''
_format_version: "1.1"
services:
  - name: vault
    url: http://db:5432
    routes:
      - name: vault-route
        paths: [/vault]
  - name: ai
    url: http://ollama:11434
    routes:
      - name: ai-route
        paths: [/ai]
''');

    // 3. Generate docker-compose.yml
    final composeFile = File('$_vaultPath/docker-compose.yml');
    await composeFile.writeAsString('''
version: '3.8'
services:
  guptik-tunnel:
    image: cloudflare/cloudflared:latest
    restart: always
    environment:
      - TUNNEL_TOKEN=\${CF_TUNNEL_TOKEN}
    command: tunnel --no-autoupdate run

  db:
    image: supabase/postgres:15.1.1.78
    ports:
      - "\${POSTGRES_PORT}:5432"
    environment:
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
      - \${VAULT_PATH}:/media/vault

  ollama:
    image: ollama/ollama:latest
    volumes:
      - ./data/ollama:/root/.ollama
''');
  }

  // Fixes: "The method 'startStack' isn't defined"
  Future<void> startStack() async {
    if (_vaultPath == null) return;
    try {
      await _shell.run('cd $_vaultPath && docker-compose up -d');
    } catch (e) {
      throw Exception("Docker failed to start: $e");
    }
  }
}