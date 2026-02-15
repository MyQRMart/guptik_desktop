import 'dart:io';
import 'package:process_run/shell.dart';

class DockerService {
  String? _vaultPath;

  void setVaultPath(String path) => _vaultPath = path;

  Future<void> autoConfigure({
    required String dbPass,
    required String tunnelToken,
    required String publicUrl,
  }) async {
    if (_vaultPath == null) throw Exception("Vault path is not initialized");

    // PRE-CREATE DIRECTORIES: Prevents strict Linux Docker permission errors
    Directory('$_vaultPath/data/postgres').createSync(recursive: true);
    Directory('$_vaultPath/data/ollama').createSync(recursive: true);

    // 1. Generate .env
    final envFile = File('$_vaultPath/.env');
    final content = '''
POSTGRES_PASSWORD=$dbPass
POSTGRES_PORT=55432
CF_TUNNEL_TOKEN=$tunnelToken
PUBLIC_URL=$publicUrl
VAULT_PATH=$_vaultPath
''';
    await envFile.writeAsString(content);
    
    // 2. Generate kong.yml (Routing Gateway)
    final kongFile = File('$_vaultPath/kong.yml');
    await kongFile.writeAsString('''
_format_version: "1.1"
services:
  - name: vault
    url: http://db:55432
    routes:
      - name: vault-route
        paths: [/vault]
  - name: ai
    url: http://ollama:55434
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

  kong:
    image: supabase/kong:2.8.1
    ports:
      - "55000:8000"
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /var/lib/kong/kong.yml
    volumes:
      - ./kong.yml:/var/lib/kong/kong.yml
    depends_on:
      - db

  db:
    image: supabase/postgres:15.1.1.78
    ports:
      - "\${POSTGRES_PORT}:55432"
    environment:
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
    volumes:
      - ./data/postgres:/var/lib/postgresql/data
      - \${VAULT_PATH}:/media/vault

  ollama:
    image: ollama/ollama:latest
    restart: unless-stopped
    volumes:
      - ./data/ollama:/root/.ollama
''');
  }

  Future<void> startStack() async {
    if (_vaultPath == null) throw Exception("Vault path not set");
    
    // THE FIX: Set the working directory natively via the Shell parameters
    final vaultShell = Shell(workingDirectory: _vaultPath);
    
    try {
      // First try the modern Docker Compose command (v2)
      await vaultShell.run('docker compose up -d');
    } catch (e) {
      try {
        // Fallback to the older Docker Compose command (v1)
        await vaultShell.run('docker-compose up -d');
      } catch (fallbackError) {
        throw Exception("Failed to start Docker. Is Docker installed and running? Error: $fallbackError");
      }
    }
  }
}