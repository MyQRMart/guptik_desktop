import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  // Define the Base URL (using the Docker port)
  final String _baseUrl = 'http://localhost:55434';

  // Check if Ollama is up and running
  Future<bool> isReady() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Pull a model and stream progress updates (FIXED CHUNK PARSING)
  Stream<String> pullModel(String modelName) async* {
    final request = http.Request('POST', Uri.parse('$_baseUrl/api/pull'));
    request.body = jsonEncode({'name': modelName});

    try {
      final streamedResponse = await request.send();

      await for (var chunk in streamedResponse.stream.transform(utf8.decoder)) {
        // Split chunks by newline to handle multiple JSONs in one stream packet
        final lines = chunk.split('\n').where((l) => l.trim().isNotEmpty);
        
        for (var line in lines) {
          try {
            final data = jsonDecode(line);
            if (data['status'] != null) {
              String msg = data['status'];
              if (data['total'] != null && data['completed'] != null) {
                final percent = (data['completed'] / data['total'] * 100).toStringAsFixed(0);
                yield "$msg ($percent%)";
              } else {
                yield msg;
              }
            }
          } catch (_) {}
        }
      }
      yield "Success";
    } catch (e) {
      yield "Error: $e";
    }
  }

  // Delete a model (REQUIRED FOR UI)
  Future<bool> deleteModel(String modelName) async {
    try {
      final request = http.Request('DELETE', Uri.parse('$_baseUrl/api/delete'));
      request.body = jsonEncode({'name': modelName});
      final response = await request.send();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // --- NEW METHODS FOR CHAT ---

  // Get list of installed models (Renamed to match previous UI code, or use as is)
  Future<List<String>> getLocalModels() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/tags'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['models'] != null) {
          return (data['models'] as List).map<String>((m) => m['name'] as String).toList();
        }
      }
    } catch (e) {
      print("Error fetching models: $e");
    }
    return [];
  }

  // Stream chat response (FIXED CHUNK PARSING)
  Stream<String> generateChatStream({
    required String model,
    required List<Map<String, String>> history,
  }) async* {
    final url = Uri.parse('$_baseUrl/api/chat');
    
    final body = jsonEncode({
      "model": model,
      "messages": history,
      "stream": true,
    });

    try {
      final request = http.Request('POST', url);
      request.body = body;
      
      final streamedResponse = await request.send();

      await for (var chunk in streamedResponse.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n').where((l) => l.trim().isNotEmpty);
        
        for (var line in lines) {
          try {
            final data = jsonDecode(line);
            if (data['message'] != null && data['message']['content'] != null) {
              yield data['message']['content'];
            }
            if (data['done'] == true) {
              break;
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      yield "\n[Error connecting to AI: $e]";
    }
  }
}