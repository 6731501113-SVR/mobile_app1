import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Base URL of the backend. Override at build/run time:
///   flutter run --dart-define=API_BASE_URL=http://192.168.1.20:3000
/// (10.0.2.2 is the host machine as seen from the Android emulator.)
const String kApiBaseUrl =
    String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:3000');

/// Error returned by the backend (`{error:{code,message,details}}`) or a
/// network failure. [message] is already user-facing Thai text.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.code = 'UNKNOWN',
    this.status,
    this.details,
  });

  final String message;
  final String code;
  final int? status;
  final Object? details;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl, http.Client? client})
      : _baseUrl = (baseUrl ?? kApiBaseUrl).replaceAll(RegExp(r'/+$'), ''),
        _http = client ?? http.Client();

  final String _baseUrl;
  final http.Client _http;

  /// Set after login / session restore.
  String? token;

  /// Called when an authenticated request gets 401 (expired or revoked token).
  void Function()? onUnauthorized;

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);

  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body ?? const <String, dynamic>{});

  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body ?? const <String, dynamic>{});

  Future<dynamic> patch(String path, {Object? body}) =>
      _send('PATCH', path, body: body ?? const <String, dynamic>{});

  Future<dynamic> putMultipart(
    String path, {
    required String fieldName,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl$path'))
      ..headers['accept'] = 'application/json';
    final sentToken = token;
    if (sentToken != null) {
      request.headers['authorization'] = 'Bearer $sentToken';
    }
    request.files.add(
      http.MultipartFile.fromBytes(
        fieldName,
        bytes,
        filename: fileName,
        contentType: MediaType.parse(contentType),
      ),
    );

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(const Duration(seconds: 15));
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException('เซิร์ฟเวอร์ตอบสนองช้าเกินไป กรุณาลองอีกครั้ง', code: 'NETWORK');
    } on http.ClientException {
      throw const ApiException(
        'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต',
        code: 'NETWORK',
      );
    }

    return _decodeResponse(response, sentToken);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    var uri = Uri.parse('$_baseUrl$path');
    if (query != null && query.isNotEmpty) {
      uri = uri.replace(queryParameters: query);
    }

    final request = http.Request(method, uri)
      ..headers['accept'] = 'application/json'
      ..headers['content-type'] = 'application/json; charset=utf-8';
    final sentToken = token;
    if (sentToken != null) {
      request.headers['authorization'] = 'Bearer $sentToken';
    }
    if (body != null) {
      request.body = jsonEncode(body);
    }

    final http.Response res;
    try {
      final streamed = await _http
          .send(request)
          .timeout(const Duration(seconds: 15));
      res = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw const ApiException(
        'เซิร์ฟเวอร์ตอบสนองช้าเกินไป กรุณาลองอีกครั้ง',
        code: 'NETWORK',
      );
    } on http.ClientException {
      throw const ApiException(
        'เชื่อมต่อเซิร์ฟเวอร์ไม่ได้ กรุณาตรวจสอบอินเทอร์เน็ต',
        code: 'NETWORK',
      );
    }

    return _decodeResponse(res, sentToken);
  }

  dynamic _decodeResponse(http.Response response, String? sentToken) {
    dynamic json;
    if (response.bodyBytes.isNotEmpty) {
      try {
        json = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        json = null;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) return json;

    String code = 'HTTP_${response.statusCode}';
    String message = 'เกิดข้อผิดพลาด (${response.statusCode})';
    Object? details;
    if (json is Map && json['error'] is Map) {
      final err = json['error'] as Map;
      code = (err['code'] as String?) ?? code;
      message = (err['message'] as String?) ?? message;
      details = err['details'];
    } else if (json is Map && json['message'] is String) {
      message = json['message'] as String;
    }

    // Only treat as "session expired" when we actually sent a token.
    if (response.statusCode == 401 && sentToken != null) onUnauthorized?.call();

    throw ApiException(message, code: code, status: response.statusCode, details: details);
  }
}
