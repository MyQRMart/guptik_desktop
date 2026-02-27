import 'package:flutter/material.dart';
import '../../services/external/postgres_service.dart';
import 'datatables_logic.dart';

class DatatablesScreen extends StatefulWidget {
  const DatatablesScreen({super.key});

  @override
  State<DatatablesScreen> createState() => _DatatablesScreenState();
}

class _DatatablesScreenState extends State<DatatablesScreen> {
  final PostgresService _postgres = PostgresService();
  final DatatablesLogic _logic = DatatablesLogic();
  
  String? _selectedTable;
  List<String> _tables = [];
  List<Map<String, dynamic>> _data = [];
  List<String> _columns = [];

  // Define default tables that cannot be deleted
  final List<String> _defaultTables = [
    'vault_files',
    'trust_me_messages',
    'ollama_models',
    'ollama_chat_memory'
  ];

  @override
  void initState() {
    super.initState();
    _loadTables();
  }

  Future<void> _loadTables() async {
    final tables = await _postgres.getTableNames();
    setState(() => _tables = tables);
  }

  Future<void> _loadData(String tableName) async {
    final data = await _postgres.getTableData(tableName);
    final columns = await _postgres.getTableColumns(tableName);
    setState(() {
      _selectedTable = tableName;
      _data = data;
      _columns = columns;
    });
  }

  void _showCreateTableDialog() {
    final nameCtrl = TextEditingController();
    final colsCtrl = TextEditingController(text: 'id UUID PRIMARY KEY DEFAULT gen_random_uuid(), name TEXT');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text("Create New Table", style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Table Name', labelStyle: TextStyle(color: Colors.cyanAccent)), style: const TextStyle(color: Colors.white)),
            TextField(controller: colsCtrl, decoration: const InputDecoration(labelText: 'Columns (SQL Format)', labelStyle: TextStyle(color: Colors.cyanAccent)), style: const TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              await _logic.createTable(nameCtrl.text, colsCtrl.text);
              Navigator.pop(context);
              _loadTables();
            },
            child: const Text("Create", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  void _showRowDialog({Map<String, dynamic>? existingRow}) {
    if (_selectedTable == null || _columns.isEmpty) return;
    
    final controllers = {for (var col in _columns) col: TextEditingController(text: existingRow?[col]?.toString() ?? '')};
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(existingRow == null ? "Add Row" : "Edit Row", style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _columns.map((col) => TextField(
              controller: controllers[col],
              decoration: InputDecoration(labelText: col, labelStyle: const TextStyle(color: Colors.cyanAccent)),
              style: const TextStyle(color: Colors.white),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () async {
              final data = controllers.map((key, value) => MapEntry(key, value.text));
              if (existingRow == null) {
                await _logic.insertRow(_selectedTable!, data);
              } else {
                await _logic.updateRow(_selectedTable!, _columns.first, existingRow[_columns.first].toString(), data);
              }
              Navigator.pop(context);
              _loadData(_selectedTable!);
            },
            child: const Text("Save", style: TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              DropdownButton<String>(
                value: _selectedTable,
                hint: const Text("Select Local Table", style: TextStyle(color: Colors.white)),
                dropdownColor: const Color(0xFF1E293B),
                items: _tables.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(color: Colors.white)))).toList(),
                onChanged: (val) => val != null ? _loadData(val) : null,
              ),
              const SizedBox(width: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_box),
                label: const Text("New Table"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.cyanAccent),
                onPressed: _showCreateTableDialog,
              ),
              if (_selectedTable != null) ...[
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Add Row"),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.cyanAccent),
                  onPressed: () => _showRowDialog(),
                ),
                // Only show Delete Table button if it's NOT a default table
                if (!_defaultTables.contains(_selectedTable)) ...[
                  const SizedBox(width: 10),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    tooltip: "Drop Table",
                    onPressed: () async {
                      await _logic.deleteTable(_selectedTable!);
                      setState(() { _selectedTable = null; _data = []; _columns = []; });
                      _loadTables();
                    },
                  ),
                ],
              ]
            ],
          ),
        ),
        if (_columns.isNotEmpty)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: [
                    ..._columns.map((col) => DataColumn(label: Text(col, style: const TextStyle(color: Colors.cyanAccent)))),
                    const DataColumn(label: Text('Actions', style: TextStyle(color: Colors.cyanAccent))),
                  ],
                  rows: _data.map((row) => DataRow(
                    cells: [
                      ..._columns.map((col) => DataCell(Text(row[col]?.toString() ?? 'NULL', style: const TextStyle(color: Colors.white)))),
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.cyanAccent, size: 20),
                          onPressed: () => _showRowDialog(existingRow: row),
                        ),
                      ),
                    ],
                  )).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}