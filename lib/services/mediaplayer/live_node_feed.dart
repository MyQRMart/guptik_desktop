import 'package:http/http.dart' as http;
import '../../models/mediaplayer/player_video_model.dart';
import '../external/docker_service.dart';

class _Hit {
  final bool up;
  final DateTime at;
  _Hit(this.up) : at = DateTime.now();
}

/// Only list videos whose creator node answers. Catalog is hosted; bytes are not.
class LiveNodeFeed {
  LiveNodeFeed._();
  static final Map<String, _Hit> _cache = {};

  static Future<bool> isUp(String raw) async {
    final base = DockerService.normalizeGatewayUrl(raw);
    if (base.isEmpty) return false;
    final cached = _cache[base];
    if (cached != null && DateTime.now().difference(cached.at) < const Duration(seconds: 45)) {
      return cached.up;
    }
    try {
      final r = await http.get(Uri.parse(base)).timeout(const Duration(seconds: 2));
      final up = r.statusCode < 500;
      _cache[base] = _Hit(up);
      return up;
    } catch (_) {
      _cache[base] = _Hit(false);
      return false;
    }
  }

  static Future<List<PlayerVideo>> onlyLive(List<PlayerVideo> videos) async {
    final urls = videos.map((v) => DockerService.normalizeGatewayUrl(v.creatorUrl)).where((u) => u.isNotEmpty).toSet();
    final map = <String, bool>{};
    await Future.wait(urls.map((u) async {
      map[u] = await isUp(u);
    }));
    return videos.where((v) => map[DockerService.normalizeGatewayUrl(v.creatorUrl)] == true).toList();
  }
}
