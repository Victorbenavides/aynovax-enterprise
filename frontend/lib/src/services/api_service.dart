import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

class ApiService {
  static const String _baseUrl = 'http://127.0.0.1:8000';

  // 1. GET ALL DOCUMENTS (For the Sidebar)
  static Future<List<Map<String, dynamic>>> getDocuments() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/v1/documents'));
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data);
      }
      return [];
    } catch (e) {
      print("Error fetching docs: $e");
      return [];
    }
  }

  // 2. UPLOAD PDF
  static Future<Map<String, dynamic>> uploadDocument(PlatformFile file) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/api/v1/ingest'));
      
      if (file.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('file', file.bytes!, filename: file.name));
      } else if (file.path != null) {
         request.files.add(await http.MultipartFile.fromPath('file', file.path!));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Upload Error: ${response.statusCode}");
      }
    } catch (e) {
      throw Exception("Connection Failed");
    }
  }

  // 3. STREAMING CHAT
  static Stream<String> sendChatQueryStream(String query, int docId) async* {
    try {
      final request = http.Request('POST', Uri.parse('$_baseUrl/api/v1/chat'));
      request.headers['Content-Type'] = 'application/json';
      
      // Sending document_id is crucial for context memory
      request.body = jsonEncode({
        "query": query,
        "document_id": docId,
        "stream": true
      });

      final response = await http.Client().send(request);

      if (response.statusCode == 200) {
        yield* response.stream.transform(utf8.decoder);
      } else {
        yield "**Error:** Server returned status ${response.statusCode}";
      }
    } catch (e) {
      yield "**Connection Error:** Is the backend running?";
    }
  }

  // 4. DELETE DOCUMENT (And its history)
  static Future<void> deleteDocument(int docId) async {
    await http.delete(Uri.parse('$_baseUrl/api/v1/documents/$docId'));
  }

  // 5. CLEAR CHAT HISTORY (Keep document)
  static Future<void> clearChatHistory(int docId) async {
    await http.delete(Uri.parse('$_baseUrl/api/v1/documents/$docId/chat'));
  }

  // 6. FETCH HISTORY
  static Future<List<Map<String, String>>> getChatHistory(int docId) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/api/v1/documents/$docId/chat'));
      
      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(utf8.decode(response.bodyBytes));
        
        // Convertimos la lista dinámica a List<Map<String, String>>
        return data.map((msg) => {
          "role": msg['role'].toString(),
          "text": msg['text'].toString()
        }).toList();
      }
      return [];
    } catch (e) {
      print("Error fetching history: $e");
      return [];
    }
  }

}