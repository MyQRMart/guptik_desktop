import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class NodeTableClient {
  static const _base = 'http://localhost:55000';

  Future<List<Map<String, dynamic>>> select(
    String table, {
    Map<String, String> eq = const {},
    String? order,
    bool ascending = true,
    int? limit,
    String? notNull,
  }) async {
    final qp = <String, String>{
      for (final e in eq.entries) 'eq_${e.key}': e.value,
      if (order != null) 'order': order,
      if (order != null) 'dir': ascending ? 'asc' : 'desc',
      if (limit != null) 'limit': '$limit',
      if (notNull != null) 'not_null': notNull,
    };
    final uri = Uri.parse('$_base/store/$table').replace(queryParameters: qp.isEmpty ? null : qp);
    final res = await http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      debugPrint('store GET $table ${res.statusCode} ${res.body}');
      throw StateError('Node store GET failed (${res.statusCode}).');
    }
    final decoded = jsonDecode(res.body);
    if (decoded is! List) return [];
    return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>?> maybeSingle(String table, Map<String, String> eq) async {
    final rows = await select(table, eq: eq, limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, dynamic>> insert(String table, Map<String, dynamic> row) async {
    final res = await http
        .post(
          Uri.parse('$_base/store/$table'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(row),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      debugPrint('store POST $table ${res.statusCode} ${res.body}');
      throw StateError('Node store insert failed (${res.statusCode}).');
    }
    return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
  }

  Future<void> update(
    String table, {
    required Map<String, String> eq,
    required Map<String, dynamic> set,
  }) async {
    final res = await http
        .patch(
          Uri.parse('$_base/store/$table'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'eq': eq, 'set': set}),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      debugPrint('store PATCH $table ${res.statusCode} ${res.body}');
      throw StateError('Node store update failed (${res.statusCode}).');
    }
  }

  Future<void> delete(String table, Map<String, String> eq) async {
    final uri = Uri.parse('$_base/store/$table').replace(
      queryParameters: {for (final e in eq.entries) 'eq_${e.key}': e.value},
    );
    final res = await http.delete(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      debugPrint('store DELETE $table ${res.statusCode} ${res.body}');
      throw StateError('Node store delete failed (${res.statusCode}).');
    }
  }
}
