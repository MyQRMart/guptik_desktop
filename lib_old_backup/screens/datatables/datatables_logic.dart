import '../../services/external/postgres_service.dart';

class DatatablesLogic {
  final PostgresService _postgres = PostgresService();

  Future<void> createAdvancedTable(String tableName, List<Map<String, dynamic>> columns) async {
    // 1. Automatically grant schema permissions to prevent the 42501 error on PostgreSQL 15+
    try {
      await _postgres.executeRawQuery('GRANT ALL ON SCHEMA public TO public;');
      print('DEBUG: Granted schema permissions successfully.');
    } catch (e) {
      print('DEBUG ERROR GRANTING SCHEMA PERMISSIONS: $e');
    }

    // 2. Build Columns
    List<String> colDefs = [];
    for (var col in columns) {
      final colName = col['name'].toString().trim();
      if (colName.isEmpty) continue; 

      String def = '"$colName" ${col['type']}';
      if (col['isPk'] == true) def += ' PRIMARY KEY';
      if (col['isUnique'] == true) def += ' UNIQUE';
      if (col['isNullable'] == false && col['isPk'] != true) def += ' NOT NULL';
      
      if (col['defVal'] != null && col['defVal'].toString().trim().isNotEmpty) {
        String defaultVal = col['defVal'].toString().trim();
        if (col['type'] == 'TEXT' && !defaultVal.contains('(')) {
           defaultVal = "'$defaultVal'";
        }
        def += ' DEFAULT $defaultVal';
      }
      colDefs.add(def);
    }

    if (colDefs.isEmpty) throw Exception("No valid columns defined");

    // 3. Execute Creation
    final query = 'CREATE TABLE IF NOT EXISTS "$tableName" (${colDefs.join(', ')})';
    print('DEBUG SQL QUERY: $query');
    await _postgres.executeRawQuery(query);
  }

  Future<void> insertRow(String tableName, Map<String, dynamic> data) async {
    final filteredData = data.entries.where((e) => e.value != null && e.value.toString().isNotEmpty);
    if (filteredData.isEmpty) return;

    final columns = filteredData.map((e) => '"${e.key}"').join(', ');
    final values = filteredData.map((e) => e.value == 'true' || e.value == 'false' ? e.value : "'${e.value}'").join(', ');
    final query = 'INSERT INTO "$tableName" ($columns) VALUES ($values)';
    await _postgres.executeRawQuery(query);
  }

  Future<void> updateRow(String tableName, String idColumn, String idValue, Map<String, dynamic> data) async {
    final updates = data.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) => e.value == 'true' || e.value == 'false' ? '"${e.key}" = ${e.value}' : '"${e.key}" = \'${e.value}\'')
        .join(', ');
    if (updates.isEmpty) return;
    
    final query = 'UPDATE "$tableName" SET $updates WHERE "$idColumn" = \'$idValue\'';
    await _postgres.executeRawQuery(query);
  }

  Future<void> deleteTable(String tableName) async {
    await _postgres.executeRawQuery('DROP TABLE IF EXISTS "$tableName" CASCADE');
  }
  
  Future<void> deleteRow(String tableName, String idColumn, String idValue) async {
    await _postgres.executeRawQuery('DELETE FROM "$tableName" WHERE "$idColumn" = \'$idValue\'');
  }
}