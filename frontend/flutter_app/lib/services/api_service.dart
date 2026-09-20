import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/sign_in_page.dart';

class ApiService {
  // 10.0.2.2 is the special alias for your computer's localhost in the Android Emulator
  static const String socketUrl = 'https://automate-72vi.onrender.com';
  static const String baseUrl = '$socketUrl/api';

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  /// Decodes JWT payload and checks if token is expired (e.g. after 7 days)
  static bool isTokenExpired(String? token) {
    if (token == null || token.trim().isEmpty) return true;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = jsonDecode(resp);

      if (payloadMap is! Map<String, dynamic>) return true;
      if (!payloadMap.containsKey('exp')) return false;

      final exp = payloadMap['exp'];
      final expSeconds = exp is int ? exp : int.parse(exp.toString());
      final expDate = DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000);

      return DateTime.now().isAfter(expDate);
    } catch (e) {
      return true;
    }
  }

  /// GET token from local storage
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  /// GET valid, non-expired token from local storage. Clears token if expired.
  static Future<String?> getValidToken() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return null;
    if (isTokenExpired(token)) {
      await clearToken();
      return null;
    }
    return token;
  }

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

  /// Automatically log out and navigate to SignInPage when unauthorized / token expired
  static void handleUnauthorized() {
    clearToken();
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const SignInPage()),
        (route) => false,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Session expired. Please sign in again."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  /// GET request with JWT header
  static Future<http.Response> getRequest(String endpoint) async {
    final token = await getValidToken();
    final response = await http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if ((response.statusCode == 401 || response.statusCode == 403) &&
        endpoint != '/auth/login' &&
        endpoint != '/auth/register') {
      handleUnauthorized();
    }

    return response;
  }

  /// POST request with JWT header
  static Future<http.Response> postRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await getValidToken();
    final response = await http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if ((response.statusCode == 401 || response.statusCode == 403) &&
        endpoint != '/auth/login' &&
        endpoint != '/auth/register') {
      handleUnauthorized();
    }

    return response;
  }

  /// PUT request with JWT header
  static Future<http.Response> putRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final token = await getValidToken();
    final response = await http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    );

    if ((response.statusCode == 401 || response.statusCode == 403) &&
        endpoint != '/auth/login' &&
        endpoint != '/auth/register') {
      handleUnauthorized();
    }

    return response;
  }
}

