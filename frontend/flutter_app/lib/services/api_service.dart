import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // 10.0.2.2 is the special alias for your computer's localhost in the Android Emulator
  static const String baseUrl = 'http://10.0.2.2:3000/api';

  /// GET token from local storage
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }
  // Add this inside api_service.dart if you don't have it yet!
  static Future<void> removeToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  /// SAVE token to local storage (called after login/register)
  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  /// REMOVE token (called on logout)
  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  /// GET request with JWT header
  static Future<http.Response> getRequest(String endpoint) async {
    final token = await getToken();
    return await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );
  }

  /// POST request with JWT header
  static Future<http.Response> postRequest(String endpoint, Map<String, dynamic> body) async {
    final token = await getToken();
    return await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );
  }
}