import 'dart:io';
import 'package:process_run/shell.dart';

class DockerService {
  final Shell _shell = Shell();

  /// Checks if Docker is installed
  Future<bool> isDockerInstalled() async {
    try {
      await _shell.run('docker --version');
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Starts the external services stack
  Future<void> startServices() async {
    // We assume a docker-compose.yml exists in the app's document directory
    // This command starts n8n and local supabase
    try {
      await _shell.run('docker-compose -f assets/docker-compose.yml up -d');
      print("External services started");
    } catch (e) {
      print("Error starting services: $e");
    }
  }

  /// Stops the services to save RAM
  Future<void> stopServices() async {
    await _shell.run('docker-compose -f assets/docker-compose.yml down');
  }
}