import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class NexusServer {
  HttpServer? _server;
  final int port = 8080; // The port Mobile Apps will connect to

  // Active "Trust Me" Sockets
  final Map<String, WebSocketChannel> _activeSockets = {};

  Future<void> start() async {
    final router = Router();

    // 1. VAULT: Upload Endpoint
    router.post('/vault/upload', (Request request) async {
      // Logic to stream file to local disk
      // In a real app, use mime_multipart to parse the body
      return Response.ok('File received');
    });

    // 2. VAULT: Download Endpoint
    router.get('/vault/file/<fileId>', (Request request, String fileId) {
      final file = File('path_to_storage/$fileId');
      if (!file.existsSync()) return Response.notFound('File not found');
      return Response.ok(file.openRead(), headers: {
        'Content-Type': 'application/octet-stream',
      });
    });

    // 3. TRUST ME: WebSocket Relay
    router.get('/ws/trust_me', webSocketHandler((WebSocketChannel webSocket) {
      webSocket.stream.listen((message) {
        _handleTrustMessage(webSocket, message);
      });
    }));

    // Start the server
    final handler = Pipeline().addMiddleware(logRequests()).addHandler(router.call);
    _server = await io.serve(handler, InternetAddress.anyIPv4, port);
    print('Nexus Server running on port ${_server?.port}');
  }

  void _handleTrustMessage(WebSocketChannel client, dynamic message) {
    // Parse JSON: { "type": "signal", "target_user": "uuid", "payload": "..." }
    // Forward payload to the target user if they are connected
    print("Relaying Trust Me packet: $message");
  }

  Future<void> stop() async {
    await _server?.close();
  }
}