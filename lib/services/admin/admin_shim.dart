import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Drop-in for hosted Supabase. Talks to guptik-admin JS at https://guptik.com
class User {
  final String id;
  final String email;
  final Map<String, dynamic> userMetadata;
  User({required this.id, required this.email, this.userMetadata = const {}});
  String? get phone => userMetadata['phone']?.toString();
}

class Session {
  final User user;
  final String accessToken;
  Session({required this.user, required this.accessToken});
}

class AuthResponse {
  final User? user;
  final Session? session;
  AuthResponse({this.user, this.session});
}

class AuthState {
  final Session? session;
  AuthState(this.session);
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

enum OAuthProvider { google }

class FileOptions {
  final bool upsert;
  const FileOptions({this.upsert = false});
}

class RealtimeChannel {
  Future<RealtimeChannel> subscribe() async => this;
  Future<void> unsubscribe() async {}
  Future<void> sendBroadcastMessage({required String event, required Map payload}) async {}
  RealtimeChannel on(dynamic event, dynamic cb) => this;
}

class _StorageFile {
  Future<String> uploadBinary(String path, dynamic bytes, {FileOptions? fileOptions}) async => path;
  String getPublicUrl(String path) => 'https://guptik.com/storage/$path';
}

class _Storage {
  _StorageFile from(String bucket) => _StorageFile();
}

class GotrueClient {
  Session? _session;
  final _ctrl = StreamController<AuthState>.broadcast();

  User? get currentUser => _session?.user;
  Session? get currentSession => _session;
  Stream<AuthState> get onAuthStateChange => _ctrl.stream;

  Future<AuthResponse> signInWithPassword({required String email, required String password}) async {
    final r = await AdminHttp.post('/auth/login', {'email': email, 'password': password}, auth: false);
    if (r['error'] != null) throw AuthException(r['error'].toString());
    final user = User(id: r['user']['id'].toString(), email: r['user']['email'].toString());
    _session = Session(user: user, accessToken: r['token'].toString());
    await AdminHttp.saveToken(_session!.accessToken, user.id, user.email);
    _ctrl.add(AuthState(_session));
    return AuthResponse(user: user, session: _session);
  }

  Future<AuthResponse> signUp({required String email, required String password, Map<String, dynamic>? data}) async {
    final r = await AdminHttp.post('/auth/register', {'email': email, 'password': password}, auth: false);
    if (r['error'] != null) throw AuthException(r['error'].toString());
    final user = User(id: r['user']['id'].toString(), email: r['user']['email'].toString());
    _session = Session(user: user, accessToken: r['token'].toString());
    await AdminHttp.saveToken(_session!.accessToken, user.id, user.email);
    _ctrl.add(AuthState(_session));
    return AuthResponse(user: user, session: _session);
  }

  Future<AuthResponse> signInWithToken(String token) async {
    await AdminHttp.saveToken(token, 'pending', '');
    await restore();
    if (_session == null) throw AuthException('google session');
    return AuthResponse(user: currentUser, session: _session);
  }

  Future<String?> signInWithOAuth(OAuthProvider provider, {String? redirectTo}) async {
    throw AuthException('Use Continue with Google on this screen.');
  }

  Future<void> signOut() async {
    _session = null;
    await AdminHttp.clearToken();
    _ctrl.add(AuthState(null));
  }

  Future<void> restore() async {
    final t = await AdminHttp.loadToken();
    if (t == null) {
      _ctrl.add(AuthState(null));
      return;
    }
    final r = await AdminHttp.get('/auth/me');
    if (r['user'] == null) {
      await AdminHttp.clearToken();
      _ctrl.add(AuthState(null));
      return;
    }
    final user = User(id: r['user']['id'].toString(), email: r['user']['email'].toString());
    _session = Session(user: user, accessToken: t);
    _ctrl.add(AuthState(_session));
  }
}

class AdminFilter implements Future<dynamic> {
  final String table;
  final Map<String, String> _eq = {};
  String? _or;
  String? _order;
  int? _limit;
  String _op = 'get';
  Map<String, dynamic>? _body;
  String? _onConflict;
  bool _one = false;
  bool _maybe = false;

  AdminFilter(this.table);

  AdminFilter select([String cols = '*']) => this;
  AdminFilter eq(String k, dynamic v) {
    _eq[k] = 'eq.$v';
    return this;
  }
  AdminFilter match(Map<String, dynamic> m) {
    m.forEach((k, v) => eq(k, v));
    return this;
  }
  AdminFilter or(String expr) {
    _or = expr;
    return this;
  }
  AdminFilter order(String col, {bool ascending = true}) {
    _order = '$col.${ascending ? 'asc' : 'desc'}';
    return this;
  }
  AdminFilter limit(int n) {
    _limit = n;
    return this;
  }
  AdminFilter insert(dynamic row) {
    _op = 'post';
    if (row is List && row.isNotEmpty) {
      _body = Map<String, dynamic>.from(row.first as Map);
    } else {
      _body = Map<String, dynamic>.from(row as Map);
    }
    return this;
  }
  AdminFilter upsert(dynamic row, {String? onConflict}) {
    _op = 'post';
    _body = Map<String, dynamic>.from(row as Map);
    _onConflict = onConflict;
    return this;
  }
  AdminFilter update(dynamic row) {
    _op = 'patch';
    _body = Map<String, dynamic>.from(row as Map);
    return this;
  }
  AdminFilter delete() {
    _op = 'delete';
    return this;
  }

  Future<dynamic> maybeSingle() {
    _one = true;
    _maybe = true;
    return _run();
  }

  Future<dynamic> single() {
    _one = true;
    _maybe = false;
    return _run();
  }

  Uri _uri() {
    final q = <String, String>{..._eq};
    if (_or != null) q['or'] = _or!;
    if (_order != null) q['order'] = _order!;
    if (_limit != null) q['limit'] = '$_limit';
    if (_op == 'post' && _onConflict != null) {
      q['upsert'] = '1';
      q['on_conflict'] = _onConflict!;
    }
    return Uri.parse('${AdminHttp.base}/rest/$table').replace(queryParameters: q.isEmpty ? null : q);
  }

  Future<dynamic> _run() async {
    final headers = await AdminHttp.headers();
    http.Response r;
    if (_op == 'get') {
      r = await http.get(_uri(), headers: headers);
    } else if (_op == 'post') {
      r = await http.post(_uri(), headers: headers, body: jsonEncode(_body));
    } else if (_op == 'patch') {
      r = await http.patch(_uri(), headers: headers, body: jsonEncode(_body));
    } else {
      r = await http.delete(_uri(), headers: headers);
    }
    final decoded = r.body.isEmpty ? null : jsonDecode(r.body);
    if (r.statusCode >= 400) {
      throw AuthException((decoded is Map ? decoded['error'] : null)?.toString() ?? 'http ${r.statusCode}');
    }
    if (_op == 'post') return decoded;
    final list = decoded is List ? decoded : (decoded == null ? [] : [decoded]);
    if (_one) {
      if (list.isEmpty) {
        if (_maybe) return null;
        throw AuthException('no rows');
      }
      return list.first;
    }
    return list;
  }

  @override
  Future<R> then<R>(FutureOr<R> Function(dynamic value) onValue, {Function? onError}) =>
      _run().then(onValue, onError: onError);

  @override
  Future<dynamic> catchError(Function onError, {bool Function(Object)? test}) =>
      _run().catchError(onError, test: test);

  @override
  Future<dynamic> timeout(Duration timeLimit, {FutureOr<dynamic> Function()? onTimeout}) =>
      _run().timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<dynamic> whenComplete(FutureOr<void> Function() action) => _run().whenComplete(action);

  @override
  Stream<dynamic> asStream() => _run().asStream();
}

class AdminClient {
  final auth = GotrueClient();
  final storage = _Storage();
  AdminFilter from(String table) => AdminFilter(table);
  RealtimeChannel channel(String name) => RealtimeChannel();
}

class Supabase {
  static final instance = Supabase._();
  Supabase._();
  final client = AdminClient();

  static Future<void> initialize({
    required String url,
    required String anonKey,
    bool debug = false,
    Map<String, String>? headers,
  }) async {
    await instance.client.auth.restore();
  }
}

class AdminHttp {
  static const base = 'https://guptik.com';
  static const _kTok = 'guptik_admin_token';
  static const _kUid = 'guptik_admin_uid';
  static const _kEmail = 'guptik_admin_email';

  static Future<String?> loadToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kTok);
  }

  static Future<void> saveToken(String t, String id, String email) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTok, t);
    await p.setString(_kUid, id);
    await p.setString(_kEmail, email);
  }

  static Future<void> clearToken() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kTok);
    await p.remove(_kUid);
    await p.remove(_kEmail);
  }

  static Future<Map<String, String>> headers({bool auth = true}) async {
    final h = <String, String>{'Content-Type': 'application/json'};
    if (auth) {
      final t = await loadToken();
      if (t != null) h['Authorization'] = 'Bearer $t';
    }
    return h;
  }

  static Future<Map<String, dynamic>> post(String path, Map body, {bool auth = true}) async {
    final r = await http.post(Uri.parse('$base$path'), headers: await headers(auth: auth), body: jsonEncode(body));
    final d = r.body.isEmpty ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(r.body) as Map);
    if (r.statusCode >= 400 && d['error'] == null) d['error'] = 'http ${r.statusCode}';
    return d;
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final r = await http.get(Uri.parse('$base$path'), headers: await headers());
    if (r.body.isEmpty) return {};
    return Map<String, dynamic>.from(jsonDecode(r.body) as Map);
  }
}

typedef SupabaseClient = AdminClient;
