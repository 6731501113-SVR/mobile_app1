import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';

abstract class AuthRepository {
  /// Re-opens a saved session. Returns null when there is none / it expired.
  Future<AppUser?> restoreSession();

  Future<AppUser> login({required String username, required String password});

  Future<AppUser> register({
    required String username,
    required String fullName,
    required String password,
  });

  Future<void> logout();
}

// ---------------------------------------------------------------------------
// Token storage
// ---------------------------------------------------------------------------

/// Where the login token is kept. Tests use an in-memory implementation.
abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

/// Keychain / Keystore backed storage for the real app.
class SecureTokenStore implements TokenStore {
  SecureTokenStore();
  static const _key = 'auth_token';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._tokens);

  final ApiClient _api;
  final TokenStore _tokens;

  int? _userIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;

      final payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      final padded = payload.padRight((payload.length + 3) & ~3, '=');
      final decoded = utf8.decode(base64Url.decode(padded));
      final json = jsonDecode(decoded) as Map<String, dynamic>;
      return int.tryParse('${json['id']}');
    } catch (_) {
      return null;
    }
  }

  AppUser _fromBackendData(Map<String, dynamic> data) => AppUser(
        id: (data['userId'] ?? data['id']) as int,
        username: data['username'] as String,
        fullName: (data['full_name'] ?? data['fullName']) as String,
        role: (data['role'] ?? 'borrower') == 'admin'
            ? UserRole.admin
            : UserRole.borrower,
      );

  @override
  Future<AppUser?> restoreSession() async {
    final saved = await _tokens.read();
    if (saved == null) return null;

    _api.token = saved;
    final userId = _userIdFromToken(saved);
    if (userId == null) {
      await logout();
      return null;
    }

    try {
      Map<String, dynamic> j;
      try {
        j = await _api.get('/api/users/$userId') as Map<String, dynamic>;
      } on ApiException catch (e) {
        if (e.status == 404) {
          j = await _api.get('/api/auth/me') as Map<String, dynamic>;
        } else {
          rethrow;
        }
      }
      final raw = (j['data'] ?? j['user']) as Map<String, dynamic>;
      return _fromBackendData(raw);
    } on ApiException catch (e) {
      if (e.status == 401) {
        await logout();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<AppUser> login({required String username, required String password}) async {
    final j = await _api.post(
      '/api/auth/login',
      body: {'username': username, 'password': password},
    ) as Map<String, dynamic>;

    final token = j['token'] as String;
    _api.token = token;
    await _tokens.write(token);

    final raw = (j['data'] ?? j['user']) as Map<String, dynamic>;
    return _fromBackendData(raw);
  }

  @override
  Future<AppUser> register({
    required String username,
    required String fullName,
    required String password,
  }) async {
    await _api.post(
      '/api/auth/register',
      // The server creates borrowers only; a separate login call is required
      // to receive the JWT that the app keeps in storage.
      body: {'username': username, 'full_name': fullName, 'password': password},
    );

    return login(username: username, password: password);
  }

  @override
  Future<void> logout() async {
    _api.token = null;
    await _tokens.clear();
  }
}
