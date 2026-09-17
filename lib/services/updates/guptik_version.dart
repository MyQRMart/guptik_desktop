/// Bump [app] when the Flutter desktop binary changes.
/// Bump [node] when the gateway template / compose node changes.
/// They ship independently — a new app can push a node update without a full reinstall.
class GuptikVersion {
  GuptikVersion._();

  static const app = '0.2.0';
  static const node = '20260918';

  static const githubRepo = 'MyQRMart/guptik_desktop';

  static int _code(String v) {
    final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }

  static bool appNewer(String remote) => _code(remote) > _code(app);
  static bool nodeNewerThan(String? installed) =>
      _code(node) > _code(installed ?? '0');
}
