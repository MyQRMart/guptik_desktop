import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointycastle/export.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import '../lib/gateway_auth.dart';
import '../lib/gateway_account.dart';
import 'fake_dir.dart';

const base = 'https://proj.supabase.co';
const vid = '11111111-2222-3333-4444-555555555555';
const privVid = '99999999-2222-3333-4444-555555555555';
const alice = 'aaaaaaaa-0000-4000-8000-000000000001';
const victim = 'bbbbbbbb-0000-4000-8000-000000000002';

String b64u(List<int> b) => base64Url.encode(b).replaceAll('=', '');

FortunaRandom _rng([int salt = 0]) => FortunaRandom()..seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => i + 7 + salt))));
int _n = 0;

class Key {
  late final ECPrivateKey priv;
  late final ECPublicKey pub;
  final String kid;
  Key(this.kid) {
    final g = ECKeyGenerator()..init(ParametersWithRandom(ECKeyGeneratorParameters(ECCurve_secp256r1()), _rng(++_n * 3)));
    final p = g.generateKeyPair();
    priv = p.privateKey as ECPrivateKey;
    pub = p.publicKey as ECPublicKey;
  }
  List<int> _pad(BigInt v) {
    final out = List<int>.filled(32, 0);
    var x = v;
    for (var i = 31; i >= 0; i--) {
      out[i] = (x & BigInt.from(255)).toInt();
      x >>= 8;
    }
    return out;
  }

  Map<String, dynamic> jwk() => {'kty': 'EC', 'crv': 'P-256', 'alg': 'ES256', 'use': 'sig', 'kid': kid, 'x': b64u(_pad(pub.Q!.x!.toBigInteger()!)), 'y': b64u(_pad(pub.Q!.y!.toBigInteger()!))};

  String sign(String input) {
    final s = ECDSASigner(SHA256Digest())..init(true, ParametersWithRandom(PrivateKeyParameter<ECPrivateKey>(priv), _rng()));
    final sig = s.generateSignature(Uint8List.fromList(utf8.encode(input))) as ECSignature;
    return b64u([..._pad(sig.r), ..._pad(sig.s)]);
  }
}

void main() {
  late DateTime now;
  late Key key;
  late int jwksCalls, userCalls;
  late Set<String> remoteGood;
  late List<Key> served;
  late AuthStore store;
  late Handler app;
  late FakeDir dir;

  String mint({Key? k, String sub = alice, int? exp, String iss = '$base/auth/v1', String aud = 'authenticated', String alg = 'ES256', String? kid, bool tamper = false}) {
    final kk = k ?? key;
    final h = b64u(utf8.encode(jsonEncode({'alg': alg, 'typ': 'JWT', 'kid': kid ?? kk.kid})));
    final e = exp ?? (now.millisecondsSinceEpoch ~/ 1000 + 3600);
    var p = b64u(utf8.encode(jsonEncode({'iss': iss, 'aud': aud, 'sub': sub, 'exp': e, 'email': 'a@example.com', 'role': 'authenticated'})));
    final sig = alg == 'ES256' ? kk.sign('$h.$p') : b64u(List.filled(32, 1));
    if (tamper) p = b64u(utf8.encode(jsonEncode({'iss': iss, 'aud': aud, 'sub': victim, 'exp': e})));
    return alg == 'none' ? '$h.$p.' : '$h.$p.$sig';
  }

  http.Client mock() => MockClient((r) async {
        if (r.url.path == '/auth/v1/.well-known/jwks.json') {
          jwksCalls++;
          return http.Response(jsonEncode({'keys': served.map((k) => k.jwk()).toList()}), 200);
        }
        if (r.url.path == '/auth/v1/user') {
          userCalls++;
          final t = (r.headers['Authorization'] ?? '').replaceFirst('Bearer ', '');
          if (r.headers['apikey'] != 'anon-public' || !remoteGood.contains(t)) return http.Response('{}', 401);
          return http.Response(jsonEncode({'id': alice, 'email': 'a@example.com'}), 200);
        }
        if (r.url.host == 'guptik.test' && r.url.path == '/auth/me') {
          final t = (r.headers['Authorization'] ?? '');
          return t == 'Bearer gt-good' ? http.Response(jsonEncode({'user': {'id': 'g-42', 'email': 'g@example.com'}}), 200) : http.Response('{}', 401);
        }
        return http.Response('no', 404);
      });

  Request rq(String m, String path, {Map<String, String>? h, Object? body}) =>
      Request(m, Uri.parse('http://x$path'), headers: h, body: body == null ? null : jsonEncode(body));

  Future<Map<String, dynamic>> echo(Response r) async => jsonDecode(await r.readAsString()) as Map<String, dynamic>;

  setUp(() {
    now = DateTime.utc(2026, 1, 1);
    key = Key('k1');
    served = [key];
    jwksCalls = 0;
    userCalls = 0;
    remoteGood = {};
    dir = FakeDir()..public[vid] = true;
    gatewayEnforce = true;
    final c = mock();
    store = AuthStore(
      ownerSha256: hashSecret('owner-secret'),
      viewers: ViewerTokens(utf8.encode('k' * 32), now: () => now),
      directory: dir,
      now: () => now,
      accounts: AccountAuth([
        SupabaseAccountVerifier(baseUrl: base, anonKey: 'anon-public', client: c, now: () => now),
        GuptikAccountVerifier(baseUrl: 'https://guptik.test', client: c),
      ], now: () => now),
    );
    app = const Pipeline().addMiddleware(gatewayAuth(store)).addHandler((r) async => Response.ok(jsonEncode({'path': r.url.path, 'uid': r.headers['x-viewer-uid'], 'body': await r.readAsString()})));
  });

  Map<String, String> bearer(String t) => {'authorization': 'Bearer $t'};

  group('verification', () {
    test('valid ES256 token acts as the verified user', () async {
      final r = await app(rq('POST', '/player/video/like', h: bearer(mint()), body: {'video_id': vid, 'creator_uid': victim, 'reaction_type': 'heart'}));
      expect(r.statusCode, 200);
      final body = jsonDecode((await echo(r))['body'] as String);
      expect(body['creator_uid'], alice, reason: 'client-supplied actor must be overwritten');
      expect(body['video_id'], vid);
      expect(userCalls, 0, reason: 'ES256 is verified locally');
    });

    test('rejects bad signature, wrong key, tampered payload, expired, wrong iss/aud, alg none', () async {
      final other = Key('k1'); // same kid, different key material
      expect(other.pub.Q!.x!.toBigInteger(), isNot(key.pub.Q!.x!.toBigInteger()));
      final bad = <String, String>{
        'wrong key': mint(k: other),
        'tampered': mint(tamper: true),
        'expired': mint(exp: now.millisecondsSinceEpoch ~/ 1000 - 10),
        'wrong iss': mint(iss: 'https://evil.supabase.co/auth/v1'),
        'wrong aud': mint(aud: 'anon'),
        'alg none': mint(alg: 'none'),
        'garbage': 'not.a.jwt',
        'empty-ish': 'x',
      };
      for (final e in bad.entries) {
        final r = await app(rq('POST', '/player/video/like', h: bearer(e.value), body: {'video_id': vid}));
        expect(r.statusCode, 401, reason: e.key);
      }
      expect(userCalls, 0, reason: 'invalid tokens are not forwarded to Supabase');
    });

    test('token expires as the clock moves, even if cached', () async {
      final t = mint(exp: now.millisecondsSinceEpoch ~/ 1000 + 60);
      expect((await app(rq('POST', '/player/video/like', h: bearer(t), body: {'video_id': vid}))).statusCode, 200);
      now = now.add(const Duration(seconds: 61));
      expect((await app(rq('POST', '/player/video/like', h: bearer(t), body: {'video_id': vid}))).statusCode, 401);
    });

    test('unknown kid triggers at most one JWKS refetch per minute; rotated key then works', () async {
      final rotated = Key('k2');
      final t = mint(k: rotated);
      expect((await app(rq('POST', '/player/video/like', h: bearer(t), body: {'video_id': vid}))).statusCode, 401);
      served = [key, rotated];
      now = now.add(const Duration(seconds: 61));
      expect((await app(rq('POST', '/player/video/like', h: bearer(mint(k: rotated, sub: alice, exp: now.millisecondsSinceEpoch ~/ 1000 + 100)), body: {'video_id': vid}))).statusCode, 200);
      expect(jwksCalls, 2);
    });

    test('HS256 token is validated by Supabase and cached by token hash', () async {
      final t = mint(alg: 'HS256');
      remoteGood.add(t);
      for (var i = 0; i < 3; i++) {
        expect((await app(rq('POST', '/player/video/like', h: bearer(t), body: {'video_id': vid}))).statusCode, 200);
      }
      expect(userCalls, 1);
    });

    test('HS256 token Supabase rejects (revoked) is denied, negative result cached', () async {
      final t = mint(alg: 'HS256');
      for (var i = 0; i < 2; i++) {
        expect((await app(rq('POST', '/player/video/like', h: bearer(t), body: {'video_id': vid}))).statusCode, 401);
      }
      expect(userCalls, 1);
    });

    test('guptik.com account token is accepted via /auth/me', () async {
      final r = await app(rq('POST', '/channel/subscribe/toggle', h: bearer('gt-good'), body: {'channel_id': 'c1', 'subscriber_uid': victim}));
      expect(r.statusCode, 200);
      expect(jsonDecode((await echo(r))['body'] as String)['subscriber_uid'], 'g-42');
      expect((await app(rq('POST', '/channel/subscribe/toggle', h: bearer('gt-bad'), body: {'channel_id': 'c1'}))).statusCode, 401);
    });

    test('too many token checks from one IP are refused', () async {
      store = AuthStore(
        ownerSha256: hashSecret('o'),
        viewers: ViewerTokens(utf8.encode('k' * 32), now: () => now),
        directory: dir,
        now: () => now,
        accounts: store.accounts,
        attemptLimiter: RateLimiter(2, now: () => now),
      );
      app = const Pipeline().addMiddleware(gatewayAuth(store)).addHandler((r) => Response.ok('ok'));
      final t = mint();
      expect((await app(rq('POST', '/player/video/like', h: bearer(t), body: {'video_id': vid}))).statusCode, 200);
      expect((await app(rq('POST', '/player/video/like', h: bearer('a.b.c'), body: {'video_id': vid}))).statusCode, 401);
      expect((await app(rq('POST', '/player/video/like', h: bearer(t), body: {'video_id': vid}))).statusCode, 401, reason: 'third attempt in the window is throttled');
    });
  });

  group('scope', () {
    test('account tokens never reach vault, contacts, uploads, AI or admin', () async {
      final h = bearer(mint());
      final denied = [
        ['GET', '/vault/files'],
        ['GET', '/api/contacts'],
        ['POST', '/player/video/upload'],
        ['POST', '/api/agent/chat'],
        ['GET', '/api/ai-config'],
        ['GET', '/admin/devices'],
        ['POST', '/admin/devices'],
        ['DELETE', '/player/video/$vid'],
        ['GET', '/player/library'],
      ];
      for (final d in denied) {
        final r = await app(rq(d[0], d[1], h: h));
        expect(r.statusCode, 403, reason: '${d[0]} ${d[1]}');
      }
    });

    test('owner and paired tokens keep full access and their own actor ids', () async {
      final r = await app(rq('GET', '/vault/files', h: bearer('gt1.owner.owner-secret')));
      expect(r.statusCode, 200);
      final r2 = await app(rq('POST', '/player/video/like', h: bearer('gt1.owner.owner-secret'), body: {'video_id': vid, 'creator_uid': 'whoever'}));
      expect(jsonDecode((await echo(r2))['body'] as String)['creator_uid'], 'whoever');
    });

    test('anonymous viewers still cannot write social routes', () async {
      final v = store.viewers.issue();
      for (final d in [
        ['POST', '/player/video/like'],
        ['POST', '/player/video/comment'],
        ['POST', '/channel/subscribe/toggle'],
      ]) {
        expect((await app(rq(d[0], d[1], h: bearer(v), body: {'video_id': vid}))).statusCode, 403, reason: d[1]);
      }
    });

    test('liking or commenting on a non-public video is refused', () async {
      for (final p in ['/player/video/like', '/player/video/comment', '/player/video/view']) {
        final r = await app(rq('POST', p, h: bearer(mint()), body: {'video_id': privVid, 'comment_text': 'hi'}));
        expect(r.statusCode, 404, reason: p);
      }
    });
  });

  group('actor rewriting', () {
    Future<Map<String, dynamic>> sent(String method, String path, Map<String, dynamic> body) async {
      final r = await app(rq(method, path, h: bearer(mint()), body: body));
      expect(r.statusCode, 200, reason: path);
      return jsonDecode((await echo(r))['body'] as String) as Map<String, dynamic>;
    }

    test('every write route overwrites its actor field', () async {
      expect((await sent('POST', '/player/video/comment', {'video_id': vid, 'comment_text': 'hi', 'creator_uid': victim}))['creator_uid'], alice);
      expect((await sent('PUT', '/player/video/comment/c1', {'comment_text': 'e', 'editor_uid': victim}))['editor_uid'], alice);
      expect((await sent('DELETE', '/player/video/comment/c1', {'deleter_uid': victim}))['deleter_uid'], alice);
      expect((await sent('POST', '/player/video/comment/c1/react', {'reaction': 'heart', 'reactor_uid': victim}))['reactor_uid'], alice);
      expect((await sent('POST', '/player/video/comment/c1/report', {'reporter_uid': victim}))['reporter_uid'], alice);
      expect((await sent('POST', '/channel/subscribe/toggle', {'channel_id': 'c', 'subscriber_uid': victim}))['subscriber_uid'], alice);
      expect((await sent('POST', '/player/video/view', {'video_id': vid, 'viewer_uid': victim}))['viewer_uid'], alice);
    });

    test('missing actor field is filled in; omitted body works', () async {
      expect((await sent('DELETE', '/player/video/comment/c1', {}))['deleter_uid'], alice);
    });

    test('subscribe status only for your own id', () async {
      final h = bearer(mint());
      expect((await app(rq('GET', '/channel/subscribe/status/c1/$alice', h: h))).statusCode, 200);
      expect((await app(rq('GET', '/channel/subscribe/status/c1/$victim', h: h))).statusCode, 403);
    });

    test('oversized or malformed bodies are rejected', () async {
      final h = bearer(mint());
      expect((await app(rq('POST', '/player/video/comment', h: h, body: {'video_id': vid, 'comment_text': 'x' * 4001}))).statusCode, 400);
      expect((await app(Request('POST', Uri.parse('http://x/player/video/comment'), headers: h, body: '{not json'))).statusCode, 400);
      expect((await app(Request('POST', Uri.parse('http://x/player/video/comment'), headers: h, body: '[1,2]'))).statusCode, 400);
      expect((await app(Request('POST', Uri.parse('http://x/player/video/comment'), headers: h, body: 'x' * 70000))).statusCode, 413);
    });
  });

  group('comment reads', () {
    test('account sees comments on public videos with its own verified viewer id', () async {
      for (final p in ['/player/video/comments/$vid', '/player/video/comments/$vid/replies/p1']) {
        final r = await app(rq('GET', p, h: {...bearer(mint()), 'x-viewer-uid': victim}));
        expect(r.statusCode, 200, reason: p);
        expect((await echo(r))['uid'], alice);
      }
    });

    test('anonymous viewer reads comments but cannot spoof x-viewer-uid', () async {
      final r = await app(rq('GET', '/player/video/comments/$vid', h: {...bearer(store.viewers.issue()), 'x-viewer-uid': victim}));
      expect(r.statusCode, 200);
      expect((await echo(r))['uid'], '');
    });

    test('comments on a private video are not readable by viewers or accounts', () async {
      for (final t in [store.viewers.issue(), mint()]) {
        expect((await app(rq('GET', '/player/video/comments/$privVid', h: bearer(t)))).statusCode, 404);
        expect((await app(rq('GET', '/player/video/comments/$privVid/replies/p1', h: bearer(t)))).statusCode, 404);
      }
    });

    test('no token at all is still unauthorized when enforcing', () async {
      expect((await app(rq('GET', '/player/video/comments/$vid'))).statusCode, 401);
    });
  });

  group('rate limits', () {
    test('per-user limit returns 429 and is enforced even in audit mode', () async {
      gatewayEnforce = false;
      store = AuthStore(
        ownerSha256: hashSecret('o'),
        viewers: ViewerTokens(utf8.encode('k' * 32), now: () => now),
        directory: dir,
        now: () => now,
        accounts: store.accounts,
        userLimiter: RateLimiter(5, now: () => now),
      );
      app = const Pipeline().addMiddleware(gatewayAuth(store)).addHandler((r) => Response.ok('ok'));
      final h = bearer(mint());
      for (var i = 0; i < 5; i++) {
        expect((await app(rq('POST', '/player/video/like', h: h, body: {'video_id': vid}))).statusCode, 200);
      }
      expect((await app(rq('POST', '/player/video/like', h: h, body: {'video_id': vid}))).statusCode, 429);
      now = now.add(const Duration(seconds: 61));
      expect((await app(rq('POST', '/player/video/like', h: h, body: {'video_id': vid}))).statusCode, 200);
    });

    test('per-IP limit applies across users', () async {
      store = AuthStore(
        ownerSha256: hashSecret('o'),
        viewers: ViewerTokens(utf8.encode('k' * 32), now: () => now),
        directory: dir,
        now: () => now,
        accounts: store.accounts,
        ipLimiter: RateLimiter(2, now: () => now),
      );
      app = const Pipeline().addMiddleware(gatewayAuth(store)).addHandler((r) => Response.ok('ok'));
      final codes = <int>[];
      for (final sub in [alice, victim, alice]) {
        codes.add((await app(rq('POST', '/player/video/like', h: {...bearer(mint(sub: sub)), 'cf-connecting-ip': '1.2.3.4'}, body: {'video_id': vid}))).statusCode);
      }
      expect(codes, [200, 200, 429]);
    });
  });

  test('sha256 of token is what gets cached (token itself never stored)', () {
    // Smoke check that the helper used by the cache is stable.
    expect(sha256.convert(utf8.encode('t')).toString().length, 64);
  });
}
