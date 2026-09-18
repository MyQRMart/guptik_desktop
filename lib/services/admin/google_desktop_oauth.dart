import 'dart:io';
import 'package:url_launcher/url_launcher.dart';
import 'admin_shim.dart';

Future<AuthResponse> signInWithGoogleDesktop() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final port = server.port;
  final url = Uri.parse('${AdminHttp.base}/auth/google/start?loop=$port');
  final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
  if (!ok) {
    await server.close(force: true);
    throw AuthException('Could not open browser');
  }
  try {
    final req = await server.first.timeout(const Duration(minutes: 3));
    final token = req.uri.queryParameters['token'] ?? '';
    req.response
      ..headers.contentType = ContentType.html
      ..write(
        '<!doctype html><html><body style="font-family:sans-serif;background:#0b1220;color:#e8e0d0;padding:40px">'
        '<p>GupTik signed in. You can close this tab.</p></body></html>',
      );
    await req.response.close();
    if (token.isEmpty) throw AuthException('Google did not return a session');
    return Supabase.instance.client.auth.signInWithToken(token);
  } finally {
    await server.close(force: true);
  }
}
