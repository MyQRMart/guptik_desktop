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

