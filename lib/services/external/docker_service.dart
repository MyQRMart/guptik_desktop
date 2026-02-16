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

    final requiredDirs = [
      '$_vaultPath/data/postgres',
      '$_vaultPath/data/ollama',
      '$_vaultPath/vault_files', 
      '$_vaultPath/gateway'
    ];

    for (var path in requiredDirs) {
      final dir = Directory(path);
      if (!dir.existsSync()) await dir.create(recursive: true);
    }

    // 1. GENERATE GATEWAY (With the new LIST Endpoint)
    await _generateGatewayFiles(publicUrl);

    // 2. Generate .env
    final envFile = File('$_vaultPath/.env');
    await envFile.writeAsString('''
POSTGRES_PASSWORD=$dbPass
POSTGRES_PORT=55432
CF_TUNNEL_TOKEN=$tunnelToken
PUBLIC_URL=$publicUrl
VAULT_PATH=$_vaultPath
''');

    // 3. Generate docker-compose.yml
    final composeFile = File('$_vaultPath/docker-compose.yml');
    await composeFile.writeAsString('''
services:
  guptik-tunnel:
    image: cloudflare/cloudflared:latest
    restart: always
    environment:
      - TUNNEL_TOKEN=\${CF_TUNNEL_TOKEN}
    command: tunnel --no-autoupdate run

  gateway:
    image: dart:stable
    working_dir: /app
    ports:
      - "55000:8080"
    volumes:
      - ./gateway:/app
      - ./vault_files:/app/storage
    command: sh -c "dart pub get && dart run server.dart"
    depends_on:
      - db
      - ollama

  db:
    image: supabase/postgres:15.1.1.78
    ports:
      - "\${POSTGRES_PORT}:5432"
    environment:
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
    volumes:
      - ./data/postgres:/var/lib/postgresql/data

  ollama:
    image: ollama/ollama:latest
    restart: unless-stopped
    ports:
      - "55434:11434"
    volumes:
      - ./data/ollama:/root/.ollama
''');
  }

  Future<void> _generateGatewayFiles(String publicUrl) async {
    final pubspec = File('$_vaultPath/gateway/pubspec.yaml');
    await pubspec.writeAsString('''
name: guptik_gateway
environment: {sdk: '>=3.0.0 <4.0.0'}
dependencies: {shelf: ^1.4.0, shelf_router: ^1.1.0, http: ^1.1.0, mime: ^1.0.4}
''');

    final server = File('$_vaultPath/gateway/server.dart');
    await server.writeAsString(r'''
import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;
import 'package:mime/mime.dart';

void main() async {
  final router = Router();

  // 1. AI Proxy
  router.post('/guptik/chat', (Request req) async {
    try {
      final payload = await req.readAsString();
      final response = await http.post(
        Uri.parse('http://ollama:11434/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: payload
      );
      return Response.ok(response.body, headers: {'Content-Type': 'application/json'});
    } catch (e) {
      return Response.internalServerError(body: 'AI Offline');
    }
  });

  // 2. Upload File
  router.post('/vault/upload/<filename>', (Request req, String filename) async {
    final file = File('/app/storage/$filename');
    await req.read().pipe(file.openWrite());
    return Response.ok(jsonEncode({'status': 'saved', 'path': filename}));
  });
  
  // 3. Download File
  router.get('/vault/files/<filename>', (Request req, String filename) async {
    final file = File('/app/storage/$filename');
    if (!await file.exists()) return Response.notFound('File not found');
    final mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    return Response.ok(file.openRead(), headers: {'Content-Type': mimeType});
  });

  // 4. LIST FILES (New Endpoint for Mobile App)
  router.get('/vault/list', (Request req) {
    final dir = Directory('/app/storage');
    if (!dir.existsSync()) return Response.ok('[]');
    
    final files = dir.listSync().whereType<File>().map((f) => {
      'name': f.uri.pathSegments.last,
      'size': f.lengthSync(),
      'modified': f.lastModifiedSync().toIso8601String()
    }).toList();
    
    return Response.ok(jsonEncode(files), headers: {'Content-Type': 'application/json'});
  });

  router.get('/', (Request req) => Response.ok('GUPTIK GATEWAY ONLINE'));

  final handler = Pipeline().addMiddleware(logRequests()).addHandler(router.call);
  final server = await serve(handler, InternetAddress.anyIPv4, 8080);
  print('Gateway listening on port ${server.port}');
}
''');
  }

  Future<void> startStack() async {
    if (_vaultPath == null) throw Exception("Vault path not set");
    
    final shell = Shell(
      workingDirectory: _vaultPath, 
      environment: Platform.environment,
      throwOnError: false
    );
    
    String dockerCmd = 'docker';
    if (Platform.isLinux || Platform.isMacOS) {
      final which = await shell.run('which docker');
      if (which.first.exitCode == 0) dockerCmd = which.first.stdout.toString().trim();
    }

    await shell.run('$dockerCmd compose pull');
    // Added --build to force the Gateway to pick up the new server.dart code
    final result = await shell.run('$dockerCmd compose up -d --build --remove-orphans');

    if (result.first.exitCode != 0) {
      throw Exception("Launch Failed: ${result.first.stderr}");
    }
  }
}