import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:guptik_desktop/services/node/node_http.dart';

void main() {
  late List<http.BaseRequest> seen;
  late NodeHttp client;

  setUp(() {
    seen = [];
    NodeHttp.accountToken = () async => 'acct-token';
    client = NodeHttp(MockClient((r) async {
      seen.add(r);
      return http.Response('{}', 200);
    }));
  });

  test('social routes on another node carry the account token', () async {
    await client.post(Uri.parse('https://peer.example/player/video/like'), body: '{}');
    await client.get(Uri.parse('https://peer.example/player/video/comments/abc'));
    await client.delete(Uri.parse('https://peer.example/player/video/comment/c1'));
    await client.post(Uri.parse('https://peer.example/channel/subscribe/toggle'), body: '{}');
    for (final r in seen) {
      expect(r.headers['Authorization'], 'Bearer acct-token', reason: r.url.path);
    }
  });

  test('other requests on another node never get the account token', () async {
    await client.get(Uri.parse('https://peer.example/vault/files/a.png'));
    await client.post(Uri.parse('https://peer.example/player/video/upload'), body: '{}');
    await client.get(Uri.parse('https://peer.example/api/contacts'));
    for (final r in seen) {
      expect(r.headers['Authorization'], isNull, reason: r.url.path);
    }
  });

  test('signed out: comment reads fall back to no account token', () async {
    NodeHttp.accountToken = () async => null;
    await client.post(Uri.parse('https://peer.example/player/video/like'), body: '{}');
    expect(seen.single.headers['Authorization'], isNull);
  });

  test('isSocial matches only the intended routes', () {
    expect(NodeHttp.isSocial('POST', '/player/video/comment/c1/react'), isTrue);
    expect(NodeHttp.isSocial('GET', '/channel/subscribe/status/c/u'), isTrue);
    expect(NodeHttp.isSocial('GET', '/player/video/stream/v'), isFalse);
    expect(NodeHttp.isSocial('POST', '/admin/devices'), isFalse);
  });
}
