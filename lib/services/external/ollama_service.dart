import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  // Define the Base URL
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

  // Pull a model and stream progress updates
  Stream<String> pullModel(String modelName) async* {
    final request = http.Request('POST', Uri.parse('$_baseUrl/api/pull'));
    request.body = jsonEncode({'name': modelName});

    try {
      final streamedResponse = await request.send();

      await for (var line in streamedResponse.stream.transform(utf8.decoder)) {
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
      yield "Success";
    } catch (e) {
      yield "Error: $e";
    }
  }

  // --- NEW METHODS FOR CHAT ---

  // Get list of installed models
  Future<List<String>> getInstalledModels() async {
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

  // Stream chat response
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

      await for (var line in streamedResponse.stream.transform(utf8.decoder)) {
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
    } catch (e) {
      yield "\n[Error connecting to AI: $e]";
    }
  }
}