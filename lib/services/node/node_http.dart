import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../admin/admin_shim.dart';
import 'node_secrets.dart';

/// HTTP client for talking to node gateways.
///  * requests to THIS PC's own gateway (localhost:55000) carry the owner token
///  * read-only player requests to other people's nodes carry a short-lived anonymous
///    viewer token (fetched from that node's POST /viewer/token and cached)
///  * like / comment / subscribe calls (and comment reads) to other people's nodes carry the signed-in
///    user's GupTik account token, so the node can verify who is acting. Only those routes get it,
///    and the paired/owner token is never sent to another node.
///  * everything else is sent untouched; the owner token never leaves localhost
class NodeHttp extends http.BaseClient {
  NodeHttp([http.Client? inner]) : _inner = inner ?? http.Client();
  final http.Client _inner;

  static final _viewerRead = RegExp(
      r'^/(player/video/(stream|thumbnail|stickers|stats|comments)|watch|channel/(profile|videos))/[^/]+$|^/player/video/comments/[^/]+/replies/[^/]+$');
  static final _socialWrite = RegExp(
      r'^/(player/video/(like|comment|view)|player/video/comment/[^/]+(/react|/report)?|channel/subscribe/toggle)$');
  static final _socialGet = RegExp(
      r'^/(player/video/comments/[^/]+(/replies/[^/]+)?|channel/subscribe/status/[^/]+/[^/]+)$');

  /// Routes where another node needs to know which signed-in user is acting.
  static bool isSocial(String method, String path) =>
      method == 'GET' ? _socialGet.hasMatch(path) : _socialWrite.hasMatch(path);

  /// The signed-in user's account token (overridable for tests).
  static Future<String?> Function() accountToken = AdminHttp.loadToken;
  static final Map<String, _ViewerToken> _viewer = {};
  static final Map<String, DateTime> _cooldown = {};

  static bool isOwnNode(Uri u) =>
      (u.host == 'localhost' || u.host == '127.0.0.1' || u.host == '::1') && u.port == 55000;

  static String _origin(Uri u) => '${u.scheme}://${u.authority}';

  /// Auth headers for widgets that cannot use this client (Image.network, video players).
  static Map<String, String> headersFor(String url) {
    final u = Uri.tryParse(url);
    if (u == null) return const {};
    if (isOwnNode(u)) {
      final t = NodeSecrets.cachedOwnerToken;
      return t == null ? const {} : {'Authorization': 'Bearer $t'};
    }
    final v = _viewer[_origin(u)];
    if (v != null && v.valid) return {'Authorization': 'Bearer ${v.token}'};
    return const {};
  }

  /// Fetches (or reuses) an anonymous viewer token for [origin]'s node.
  static Future<String?> viewerToken(Uri u) async {
    final o = _origin(u);
    final c = _viewer[o];
    if (c != null && c.valid) return c.token;
    final cool = _cooldown[o];
    if (cool != null && DateTime.now().isBefore(cool)) return null;
    try {
      final r = await http.post(Uri.parse('$o/viewer/token')).timeout(const Duration(seconds: 6));
      if (r.statusCode == 200) {
        final m = jsonDecode(r.body) as Map;
        final ttl = (m['expires_in'] as num?)?.toInt() ?? 3600;
        final t = _ViewerToken(m['token'].toString(), DateTime.now().add(Duration(seconds: ttl > 300 ? ttl - 300 : ttl)));
        _viewer[o] = t;
        return t.token;
      }
    } catch (_) {}
    // Older nodes have no /viewer/token; do not hammer them.
    _cooldown[o] = DateTime.now().add(const Duration(minutes: 2));
    return null;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!request.headers.keys.any((k) => k.toLowerCase() == 'authorization')) {
      if (isOwnNode(request.url)) {
        final t = NodeSecrets.cachedOwnerToken ?? await NodeSecrets.load();
        if (t != null) request.headers['Authorization'] = 'Bearer $t';
      } else if (isSocial(request.method, request.url.path)) {
        final a = await accountToken();
        if (a != null && a.isNotEmpty) {
          request.headers['Authorization'] = 'Bearer $a';
        } else if (request.method == 'GET' && _viewerRead.hasMatch(request.url.path)) {
          final t = await viewerToken(request.url);
          if (t != null) request.headers['Authorization'] = 'Bearer $t';
        }
      } else if (request.method == 'GET' && _viewerRead.hasMatch(request.url.path)) {
        final t = await viewerToken(request.url);
        if (t != null) request.headers['Authorization'] = 'Bearer $t';
      }
    }
    return _inner.send(request);
  }
}

class _ViewerToken {
  _ViewerToken(this.token, this.expires);
  final String token;
  final DateTime expires;
  bool get valid => DateTime.now().isBefore(expires);
}

/// Shared client; use it instead of the top-level `http` functions for node calls.
final NodeHttp nodeHttp = NodeHttp();
