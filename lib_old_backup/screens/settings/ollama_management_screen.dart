import 'package:flutter/material.dart';
import '../../services/external/ollama_service.dart';
import '../../services/external/postgres_service.dart';

class OllamaManagementScreen extends StatefulWidget {
  const OllamaManagementScreen({super.key});

  @override
  State<OllamaManagementScreen> createState() => _OllamaManagementScreenState();
}

class _OllamaManagementScreenState extends State<OllamaManagementScreen> {
  final OllamaService _ollama = OllamaService();
  final PostgresService _postgres = PostgresService();
  
  List<Map<String, dynamic>> _models = [];
  bool _isLoading = false;
  final TextEditingController _pullCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() => _isLoading = true);
    
    // 1. Get models physically on device
    final localTags = await _ollama.getLocalModels();
    
    // 2. Sync physical models to Postgres
    for (var tag in localTags) {
      await _postgres.saveOllamaModel(tag);
    }

    // 3. Fetch enriched data (with prompts) from Postgres
    final dbModels = await _postgres.getSavedModels();
    
    setState(() {
      // Only show models that actually exist in Ollama
      _models = dbModels.where((dbM) => localTags.contains(dbM['model_tag'])).toList();
      _isLoading = false;
    });
  }

  String _pullProgress = "";

  // 2. Replace the _pullModel method
  Future<void> _pullModel() async {
    final tag = _pullCtrl.text.trim();
    if (tag.isEmpty) return;

    setState(() {
      _isLoading = true;
      _pullProgress = "Starting pull...";
    });

    bool isSuccess = false;

    // Listen to the stream
    await for (String status in _ollama.pullModel(tag)) {
      setState(() => _pullProgress = status);
      if (status == "Success" || status.toLowerCase().contains("success")) {
        isSuccess = true;
      }
    }

    if (isSuccess) {
      // ✅ SAVE TO POSTGRES HERE
      await _postgres.saveOllamaModel(tag);
      _pullCtrl.clear();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Model Pulled Successfully!")));
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_pullProgress)));
    }

    setState(() {
      _isLoading = false;
      _pullProgress = "";
    });
    
    _loadModels();
  }

  Future<void> _deleteModel(String tag) async {
    setState(() => _isLoading = true);
    final success = await _ollama.deleteModel(tag);
    if (success) {
      await _postgres.deleteOllamaModelDb(tag);
    }
    _loadModels();
  }

  void _editPromptDialog(Map<String, dynamic> model) {
    final ctrl = TextEditingController(text: model['system_prompt']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text("System Prompt: ${model['model_tag']}", style: const TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(hintText: "You are a helpful AI...", hintStyle: TextStyle(color: Colors.grey)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
            onPressed: () async {
              await _postgres.updateModelPrompt(model['model_tag'], ctrl.text);
              if (mounted) Navigator.pop(context);
              _loadModels();
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text("Ollama Models", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E293B),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // PULL SECTION
            Row(
    children: [
      Expanded(
        child: TextField(
          controller: _pullCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Enter model tag (e.g., llama3, mistral)",
            hintStyle: const TextStyle(color: Colors.grey),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
        ),
      ),
      const SizedBox(width: 16),
      _isLoading 
        ? Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(8)),
              child: Text(
                _pullProgress, 
                style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          )
        : ElevatedButton.icon(
            icon: const Icon(Icons.download),
            label: const Text("Pull"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black, padding: const EdgeInsets.all(18)),
            onPressed: _pullModel,
          )
    ],
  ),
            const SizedBox(height: 20),
            
            // MODELS LIST
            Expanded(
              child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                : ListView.builder(
                    itemCount: _models.length,
                    itemBuilder: (context, index) {
                      final m = _models[index];
                      return Card(
                        color: const Color(0xFF1E293B),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(m['model_tag'], style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            m['system_prompt'].toString().isEmpty ? "No custom prompt set." : m['system_prompt'], 
                            maxLines: 2, 
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey)
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white),
                                tooltip: "Edit Prompt",
                                onPressed: () => _editPromptDialog(m),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent),
                                tooltip: "Delete Model",
                                onPressed: () => _deleteModel(m['model_tag']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            )
          ],
        ),
      ),
    );
  }
}