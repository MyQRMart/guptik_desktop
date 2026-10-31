import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';
import '../lib/gateway_auth.dart';

class FakeDir implements DeviceDirectory {
  final rows = <String, DeviceRow>{};
  final public = <String, bool>{};
  int finds = 0;
  @override
  Future<DeviceRow?> find(String id) async {
    finds++;
    return rows[id];
  }
  @override
  Future<void> touch(String id) async {}
  @override
  Future<void> create(String id, String name, String h) async => rows[id] = DeviceRow(id, name, h, null, null);
  @override
  Future<bool> revoke(String id) async {
    final r = rows[id];
    if (r == null) return false;
    rows[id] = DeviceRow(r.id, r.name, r.secretSha256, null, DateTime.now());
    return true;
  }
  @override
  Future<List<DeviceRow>> list() async => rows.values.toList();
  @override
  Future<bool> videoIsPublic(String v) async => public[v] ?? false;
}

const vid = '11111111-2222-3333-4444-555555555555';

void main() {
  late FakeDir dir;
  late AuthStore store;
  late DateTime now;
  late Handler app;
  const ownerSecret = 'owner-secret';

  Request rq(String m, String path, {Map<String, String>? h}) => Request(m, Uri.parse('http://x$path'), headers: h);

  setUp(() {
    dir = FakeDir();
    now = DateTime.utc(2026, 1, 1);
    gatewayEnforce = true;
    store = AuthStore(
      ownerSha256: hashSecret(ownerSecret),
      viewers: ViewerTokens(utf8.encode('k' * 32), now: () => now),
      directory: dir,
      now: () => now,
    );
    app = const Pipeline().addMiddleware(gatewayAuth(store)).addHandler((r) => Response.ok('ok'));
  });

  test('path safety', () {
    for (final bad in ['..', '.', '', 'a/b', '../x', r'a\b', 'x\u0000y']) {
      expect(() => safeStorageName(bad), throwsFormatException, reason: bad);
    }
    expect(safeStorageName('movie 1.mp4'), 'movie 1.mp4');
    expect(storageFile('a.mp4').path, '/app/storage/a.mp4');
  });

  test('classification', () {
    expect(classify('GET', '/'), RouteClass.open);
    expect(classify('GET', '/vault/files/a.png'), RouteClass.open);
    expect(classify('POST', '/viewer/token'), RouteClass.open);
    expect(classify('POST', '/trustme/message/receive'), RouteClass.peer);
    expect(classify('GET', '/watch/$vid'), RouteClass.viewer);
    expect(classify('GET', '/player/video/stream/$vid'), RouteClass.viewer);
    expect(classify('GET', '/channel/videos/c1'), RouteClass.viewer);
    expect(classify('POST', '/player/video/like'), RouteClass.device);
    expect(classify('POST', '/player/video/upload'), RouteClass.device);
    expect(classify('POST', '/vault/upload/a.mp4'), RouteClass.device);
    expect(classify('GET', '/player/video/comments/$vid'), RouteClass.device);
    expect(classify('DELETE', '/store/users'), RouteClass.device);
    expect(classify('GET', '/admin/devices'), RouteClass.owner);
    expect(classify('GET', '/internal/media/a.mp4'), RouteClass.device);
  });

  test('device lifecycle: create, use, revoke (cache bounds latency)', () async {
    final token = await store.createDevice('Pixel');
    final auth = {'authorization': 'Bearer $token'};
    expect((await app(rq('POST', '/player/video/like', h: auth))).statusCode, 200);
    expect((await app(rq('POST', '/player/video/like'))).statusCode, 401);
    expect((await app(rq('POST', '/player/video/like', h: {'authorization': 'Bearer ${token}x'}))).statusCode, 401);
    expect((await app(rq('POST', '/player/video/like', h: {'authorization': 'Bearer gt1.nope.abc'}))).statusCode, 401);
    expect(dir.rows.values.single.secretSha256, isNot(contains(token.split('.')[2])));
    await store.revokeDevice(token.split('.')[1]);
    expect((await app(rq('POST', '/player/video/like', h: auth))).statusCode, 401);
  });

  test('revocation from another process is picked up after the cache ttl', () async {
    final token = await store.createDevice('Pixel');
    final auth = {'authorization': 'Bearer $token'};
    expect((await app(rq('GET', '/contacts', h: auth))).statusCode, 200);
    await dir.revoke(token.split('.')[1]); // bypasses store.forget
    expect((await app(rq('GET', '/contacts', h: auth))).statusCode, 200); // still cached
    now = now.add(const Duration(seconds: 31));
    expect((await app(rq('GET', '/contacts', h: auth))).statusCode, 401);
  });

  test('owner token and admin routes', () async {
    final t = {'authorization': 'Bearer gt1.owner.$ownerSecret'};
    expect((await app(rq('GET', '/admin/devices', h: t))).statusCode, 200);
    final dev = await store.createDevice('Phone');
    final r = await app(rq('GET', '/admin/devices', h: {'authorization': 'Bearer $dev'}));
    expect(r.statusCode, 403);
    expect((await app(rq('GET', '/admin/devices'))).statusCode, 401);
    expect((await app(rq('GET', '/admin/devices', h: {'authorization': 'Bearer gt1.owner.wrong'}))).statusCode, 401);
  });

  test('admin routes stay closed in audit mode too', () async {
    gatewayEnforce = false;
    expect((await app(rq('GET', '/admin/devices'))).statusCode, 401);
    expect((await app(rq('POST', '/player/video/like'))).statusCode, 200); // audit: allowed + logged
  });

  test('viewer tokens: read-only, public only, expire, cannot be forged', () async {
    dir.public[vid] = true;
    final t = store.viewers.issue();
    final v = {'authorization': 'Bearer $t'};
    expect((await app(rq('GET', '/watch/$vid', h: v))).statusCode, 200);
    expect((await app(rq('GET', '/player/video/stream/$vid?vt=$t'))).statusCode, 200);
    expect((await app(rq('GET', '/player/video/thumbnail/$vid', h: {'x-viewer-token': t}))).statusCode, 200);
    expect((await app(rq('GET', '/channel/profile/c1', h: v))).statusCode, 200);
    // writes and device-class reads are refused
    expect((await app(rq('POST', '/vault/upload/a.mp4', h: v))).statusCode, 403);
    expect((await app(rq('POST', '/player/video/upload', h: v))).statusCode, 403);
    expect((await app(rq('POST', '/player/video/like', h: v))).statusCode, 403);
    expect((await app(rq('POST', '/channel/subscribe/toggle', h: v))).statusCode, 403);
    expect((await app(rq('GET', '/player/video/comments/$vid', h: v))).statusCode, 403);
    expect((await app(rq('GET', '/admin/devices', h: v))).statusCode, 403);
    // non public video
    dir.public[vid] = false;
    now = now.add(const Duration(seconds: 31));
    expect((await app(rq('GET', '/watch/$vid', h: v))).statusCode, 404);
    expect((await app(rq('GET', '/watch/not-a-uuid', h: v))).statusCode, 404);
    // tampering
    final parts = t.split('.');
    final forged = 'gv1.${int.parse(parts[1]) + 99999}.${parts[2]}.${parts[3]}';
    expect(store.viewers.verify(forged), isFalse);
    expect(ViewerTokens(utf8.encode('z' * 32), now: () => now).verify(t), isFalse);
    // expiry
    expect(store.viewers.verify(t), isTrue);
    now = now.add(const Duration(hours: 2));
    expect(store.viewers.verify(t), isFalse);
    expect((await app(rq('GET', '/channel/profile/c1', h: v))).statusCode, 401);
  });

  test('viewer token on a paired-only reader does not unlock device routes in audit mode logs only', () async {
    gatewayEnforce = false;
    final t = store.viewers.issue();
    expect((await app(rq('POST', '/player/video/like', h: {'authorization': 'Bearer $t'}))).statusCode, 200);
  });

  test('trustedOrAudit', () {
    gatewayEnforce = true;
    expect(trustedOrAudit(rq('GET', '/vault/files/a')), isFalse);
    expect(trustedOrAudit(rq('GET', '/vault/files/a').change(context: {'principal': const Principal(Role.device, 'd', 'n')})), isTrue);
    expect(trustedOrAudit(rq('GET', '/vault/files/a').change(context: {'principal': const Principal(Role.viewer, 'v', 'n')})), isFalse);
    gatewayEnforce = false;
    expect(trustedOrAudit(rq('GET', '/vault/files/a')), isTrue);
  });
}
