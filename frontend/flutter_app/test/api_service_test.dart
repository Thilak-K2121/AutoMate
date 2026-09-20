import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/services/api_service.dart';

void main() {
  group('JWT Expiration Tests', () {
    test('Empty or null token is expired', () {
      expect(ApiService.isTokenExpired(null), isTrue);
      expect(ApiService.isTokenExpired(''), isTrue);
      expect(ApiService.isTokenExpired('invalid.token'), isTrue);
    });

    test('Valid non-expired token returns false', () {
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))).replaceAll('=', '');
      final futureExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 7 * 24 * 3600;
      final payload = base64Url.encode(utf8.encode(jsonEncode({'id': 1, 'exp': futureExp}))).replaceAll('=', '');
      final signature = 'fake_sig';
      final token = '$header.$payload.$signature';

      expect(ApiService.isTokenExpired(token), isFalse);
    });

    test('Expired token (> 7 days past) returns true', () {
      final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))).replaceAll('=', '');
      final pastExp = (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 100;
      final payload = base64Url.encode(utf8.encode(jsonEncode({'id': 1, 'exp': pastExp}))).replaceAll('=', '');
      final signature = 'fake_sig';
      final token = '$header.$payload.$signature';

      expect(ApiService.isTokenExpired(token), isTrue);
    });
  });
}
