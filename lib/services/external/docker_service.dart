// lib/services/external/docker_service.dart
import 'dart:io';
import 'package:process_run/shell.dart';

class DockerService {
  final Shell _shell = Shell();
  String? _vaultPath;

  void setVaultPath(String path) => _vaultPath = path;

  /// Detects if Docker is available on the system
  Future<bool> isDockerReady() async {
    try {
      await _shell.run('docker --version');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Corrected method name to match InstallationScreen expectations
  Future<void> autoConfigure({
    required String dbPass,
    required String tunnelToken,
    required String publicUrl,
  }) async {
    if (_vaultPath == null) throw Exception("Vault path not set.");

    // 1. Generate .env file
    final envFile = File('$_vaultPath/.env');
    final envContent = '''
POSTGRES_PASSWORD=$dbPass
CF_TUNNEL_TOKEN=$tunnelToken
PUBLIC_URL=$publicUrl
VAULT_PATH=$_vaultPath
PROJECT_NAME=guptik_local
''';
    await envFile.writeAsString(envContent);

    // 2. Deployment logic for stack files
    // Ensure these files exist in your assets/docker/ folder
    final templates = ['docker-compose.yml', 'kong.yml'];
    for (var fileName in templates) {
      final template = File('assets/docker/$fileName');
      if (await template.exists()) {
        await template.copy('$_vaultPath/$fileName');
      }
    }
  }

  Future<void> startStack() async {
    if (_vaultPath == null) return;
    // Standard command for modern Docker Compose
    await _shell.run('cd $_vaultPath && docker compose up -d');
  }

  Future<void> stopStack() async {
    if (_vaultPath == null) return;
    await _shell.run('cd $_vaultPath && docker compose down');
  }
}