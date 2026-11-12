import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import 'auth_repository.dart';

/// State + rules for the login screen (no widgets in here, so it is unit-testable).
class LoginController extends ChangeNotifier {
  LoginController(this._repo);

  final AuthRepository _repo;

  bool _busy = false;
  String? _error;
  bool _disposed = false;

  bool get busy => _busy;
  String? get error => _error;

  static String? validateUsername(String? v) =>
      (v == null || v.trim().isEmpty) ? 'กรุณากรอกรหัสนักศึกษา' : null;

  static String? validatePassword(String? v) =>
      (v == null || v.isEmpty) ? 'กรุณากรอกรหัสผ่าน' : null;

  /// Returns the signed-in user, or null when it failed (see [error]).
  Future<AppUser?> submit({
    required String username,
    required String password,
  }) async {
    if (_busy) return null;

    final invalid = validateUsername(username) ?? validatePassword(password);
    if (invalid != null) {
      _error = invalid;
      _notify();
      return null;
    }

    _busy = true;
    _error = null;
    _notify();
    try {
      return await _repo.login(username: username.trim(), password: password);
    } on ApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = 'เชื่อมต่อไม่สำเร็จ กรุณาลองอีกครั้ง';
    } finally {
      _busy = false;
      _notify();
    }
    return null;
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
