import 'package:postgres/postgres.dart';

class PostgresService {
  static final PostgresService _instance = PostgresService._internal();
  factory PostgresService() => _instance;
  PostgresService._internal();

  // The active connection
  late Connection _connection;
  bool _isConnected = false;

  // 1. Initialize & Create User/Tables
  Future<void> initializeUserDatabase({
    required String adminPassword,
    required String email,
    required String userPassword,
  }) async {
    Connection? rootConn;
    int retries = 0;
    const int maxRetries = 300; // Will wait up to 30 seconds

    // A. Retry Loop for Docker Bootup
    while (retries < maxRetries) {
      try {
        rootConn = await Connection.open(
          Endpoint(
            host: 'localhost', 
            port: 55432,
            database: 'postgres', 
            username: 'postgres', 
            password: adminPassword
          ),
          settings: const ConnectionSettings(sslMode: SslMode.disable),
        );
        break; // Connected!
      } catch (e) {
        retries++;
        // Print the actual error so we can see what's failing in the terminal
        print("Waiting for database... ($retries/$maxRetries) | Status: ${e.toString().split('\n')[0]}");
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (rootConn == null) {
      throw Exception("Database failed to start in time.");
    }

    try {
      final safeUser = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');


      await _createTables(rootConn);
      // Create Role if not exists
      await rootConn.execute("DO \$\$ BEGIN IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$safeUser') THEN CREATE ROLE $safeUser LOGIN PASSWORD '$userPassword'; END IF; END \$\$;");
      await rootConn.execute("GRANT ALL PRIVILEGES ON DATABASE postgres TO $safeUser");
      await rootConn.execute('GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $safeUser;');
      await rootConn.execute('GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $safeUser;');
       
      // B. Close root and establish the persistent User Connection
      await rootConn.close();
      
      _connection = await Connection.open(
        Endpoint(
          host: 'localhost', 
          port: 55432, // <--- FIXED PORT
          database: 'postgres', 
          username: safeUser, 
          password: userPassword
        ),
        settings: const ConnectionSettings(sslMode: SslMode.disable),
      );
      _isConnected = true;
      print("DB: Connected as $safeUser");
      
    } catch (e) {
      print("DB Init Error: $e");
      rethrow;
    }
  }

  Future<void> connectExistingUser({
    required String email, 
    required String userPassword
  }) async {
    try {
      final safeUser = email.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      _connection = await Connection.open(
        Endpoint(
          host: 'localhost', 
          port: 55432, 
          database: 'postgres', 
          username: safeUser, 
          password: userPassword
        ),
        settings: const ConnectionSettings(sslMode: SslMode.disable),
      );
      _isConnected = true;
      print("DB: Re-connected successfully as $safeUser");
    } catch (e) {
      print("DB Re-connect Error: $e");
      rethrow;
    }
  }

  Future<void> _createTables(Connection conn) async {
    // 1. Vault Files
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS vault_files (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        file_name TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_size BIGINT,
        mime_type TEXT,
        is_favorite BOOLEAN DEFAULT FALSE,
        added_at TIMESTAMPTZ DEFAULT NOW()
      )
    ''');

    // 2. TrustMe Messages
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS trust_me_messages (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        sender_id TEXT,
        content_encrypted TEXT,
        is_read BOOLEAN DEFAULT FALSE,
        received_at TIMESTAMPTZ DEFAULT NOW()
      )
    ''');

    // 3. Ollama Models
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS ollama_models (
        model_tag TEXT PRIMARY KEY,
        size_bytes BIGINT,
        description TEXT,
        parameter_size TEXT,
        pulled_at TIMESTAMPTZ DEFAULT NOW(),
        is_active BOOLEAN DEFAULT FALSE
      )
    ''');

    // 4. Ollama Chat Memory
    await conn.execute('''
      CREATE TABLE IF NOT EXISTS ollama_chat_memory (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        session_id TEXT NOT NULL,
        model_used TEXT,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TIMESTAMPTZ DEFAULT NOW()
      )
    ''');
  }

  // --- OLLAMA CHAT OPERATIONS ---

  // 1. Save a message
  Future<void> saveChatMessage({
    required String sessionId,
    required String role, 
    required String content,
    required String model,
  }) async {
    if (!_isConnected) return;
    
    // Simple escape for single quotes
    final safeContent = content.replaceAll("'", "''");
    
    await _connection.execute('''
      INSERT INTO ollama_chat_memory (session_id, role, content, model_used)
      VALUES ('$sessionId', '$role', '$safeContent', '$model')
    ''');
  }

  // 2. Get history
  Future<List<Map<String, dynamic>>> getChatHistory(String sessionId) async {
    if (!_isConnected) return [];

    final result = await _connection.execute('''
      SELECT role, content, created_at 
      FROM ollama_chat_memory 
      WHERE session_id = '$sessionId' 
      ORDER BY created_at ASC
    ''');

    return result.map((row) {
      return {
        'role': row[0] as String,
        'content': row[1] as String,
        'created_at': row[2].toString(),
      };
    }).toList();
  }

  // 3. Get sessions
  Future<List<Map<String, dynamic>>> getChatSessions() async {
    if (!_isConnected) return [];

    // Using DISTINCT ON to get unique sessions
    final result = await _connection.execute('''
      SELECT DISTINCT ON (session_id) 
        session_id, 
        content, 
        created_at
      FROM ollama_chat_memory
      WHERE role = 'user'
      ORDER BY session_id, created_at ASC
    ''');

    final List<Map<String, dynamic>> sessions = result.map((row) {
      String snippet = (row[1] as String);
      if (snippet.length > 30) snippet = "${snippet.substring(0, 30)}...";
      
      return {
        'id': row[0] as String,
        'title': snippet,
        'date': row[2].toString(),
      };
    }).toList();
    
    // Sort in Dart (Newest first)
    sessions.sort((a, b) => b['date'].compareTo(a['date']));
    return sessions;
  }

  Future<List<String>> getTableNames() async {
    if (!_isConnected) return [];
    try {
      final result = await _connection.execute('''
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' 
        AND table_type = 'BASE TABLE';
      ''');
      return result.map((row) => row[0].toString()).toList();
    } catch (e) {
      print("Error fetching tables: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTableData(String tableName) async {
    if (!_isConnected) return [];
    try {
      final result = await _connection.execute('SELECT * FROM "$tableName"');
      return result.map((row) => row.toColumnMap()).toList();
    } catch (e) {
      print("Error fetching table data: $e");
      return [];
    }
  }

  Future<List<String>> getTableColumns(String tableName) async {
    if (!_isConnected) return [];
    try {
      final result = await _connection.execute('''
        SELECT column_name FROM information_schema.columns 
        WHERE table_schema = 'public' AND table_name = '$tableName';
      ''');
      return result.map((row) => row[0].toString()).toList();
    } catch (e) {
      print("Error fetching columns: $e");
      return [];
    }
  }

  Future<void> initOllamaTableUpdates() async {
    if (!_isConnected) return;
    try {
      // Ensure system_prompt column exists
      await _connection.execute('ALTER TABLE ollama_models ADD COLUMN IF NOT EXISTS system_prompt TEXT');
    } catch (_) {}
  }

  Future<void> saveOllamaModel(String modelTag) async {
    if (!_isConnected) return;
    await initOllamaTableUpdates();
    await _connection.execute('''
      INSERT INTO ollama_models (model_tag, is_active)
      VALUES ('$modelTag', TRUE)
      ON CONFLICT (model_tag) DO NOTHING;
    ''');
  }

  Future<void> updateModelPrompt(String modelTag, String prompt) async {
    if (!_isConnected) return;
    final safePrompt = prompt.replaceAll("'", "''");
    await _connection.execute('''
      UPDATE ollama_models SET system_prompt = '$safePrompt' WHERE model_tag = '$modelTag'
    ''');
  }

  Future<void> deleteOllamaModelDb(String modelTag) async {
    if (!_isConnected) return;
    await _connection.execute("DELETE FROM ollama_models WHERE model_tag = '$modelTag'");
  }

  Future<List<Map<String, dynamic>>> getSavedModels() async {
    if (!_isConnected) return [];
    await initOllamaTableUpdates();
    final result = await _connection.execute('SELECT model_tag, system_prompt FROM ollama_models');
    
    return result.map((r) => {
      'model_tag': r[0].toString(),
      'system_prompt': r[1]?.toString() ?? '',
    }).toList();
  }

  Future<void> saveVaultFileLocal({
    required String fileName,
    required String filePath,
    required int fileSize,
    required String mimeType,
  }) async {
    if (!_isConnected) return;
    
    final safeName = fileName.replaceAll("'", "''");
    final safePath = filePath.replaceAll("'", "''");
    
    await _connection.execute('''
      INSERT INTO vault_files (file_name, file_path, file_size, mime_type)
      VALUES ('$safeName', '$safePath', $fileSize, '$mimeType')
    ''');
  }

  Future<void> executeRawQuery(String query) async {
    if (!_isConnected) return;
    try {
      await _connection.execute(query);
    } catch (e) {
      print("Error executing query: $e");
      rethrow;
    }
  }


}