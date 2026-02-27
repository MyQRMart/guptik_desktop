import '../../services/external/postgres_service.dart';

class DatatablesLogic {
  final PostgresService _postgres = PostgresService();

  Future<void> createTable(String tableName, String columnDefinitions) async {
    final query = 'CREATE TABLE IF NOT EXISTS "$tableName" ($columnDefinitions)';
    await _postgres.executeRawQuery(query);
  }

  Future<void> insertRow(String tableName, Map<String, dynamic> data) async {
    final columns = data.keys.map((k) => '"$k"').join(', ');
    final values = data.values.map((v) => "'$v'").join(', ');
    final query = 'INSERT INTO "$tableName" ($columns) VALUES ($values)';
    await _postgres.executeRawQuery(query);
  }

  Future<void> updateRow(String tableName, String idColumn, String idValue, Map<String, dynamic> data) async {
    final updates = data.entries.map((e) => '"${e.key}" = \'${e.value}\'').join(', ');
    final query = 'UPDATE "$tableName" SET $updates WHERE "$idColumn" = \'$idValue\'';
    await _postgres.executeRawQuery(query);
  }

  Future<void> deleteTable(String tableName) async {
    await _postgres.executeRawQuery('DROP TABLE IF EXISTS "$tableName" CASCADE');
  }
}