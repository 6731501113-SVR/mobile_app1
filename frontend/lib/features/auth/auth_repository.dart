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

  @override
  Future<AppUser?> restoreSession() async {
    final saved = await _tokens.read();
    if (saved == null) return null;
    _api.token = saved;
    try {
      final j = await _api.get('/api/auth/me') as Map<String, dynamic>;
      return AppUser.fromJson(j['user'] as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.status == 401) {
        await logout();
        return null;
      }
      rethrow; // offline etc.: keep the token, let the caller offer a retry
    }
  }

  Future<AppUser> _start(dynamic json) async {
    final j = json as Map<String, dynamic>;
    final token = j['token'] as String;
    _api.token = token;
    await _tokens.write(token);
    return AppUser.fromJson(j['user'] as Map<String, dynamic>);
  }

  @override
  Future<AppUser> login({required String username, required String password}) async =>
      _start(await _api.post(
        '/api/auth/login',
        body: {'username': username, 'password': password},
      ));

  @override
  Future<AppUser> register({
    required String username,
    required String fullName,
    required String password,
  }) async =>
      _start(await _api.post(
        '/api/auth/register',
        // No role here on purpose: the server always creates borrowers.
        body: {'username': username, 'full_name': fullName, 'password': password},
      ));

  @override
  Future<void> logout() async {
    _api.token = null;
    await _tokens.clear();
  }
}
