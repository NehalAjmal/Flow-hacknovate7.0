import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String base = 'http://127.0.0.1:8002';

  static Future<Map<String, dynamic>> ping() async {
    try {
      final res = await http.get(Uri.parse('$base/api/ping'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
      return {'error': 'Server error ${res.statusCode}'};
    } catch (e) {
      return {'error': 'Cannot reach backend: $e'};
    }
  }
}