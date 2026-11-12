import 'package:flutter/foundation.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import 'auth_repository.dart';

/// State + rules for the sign-up screen.
///
/// Note: sign-up never sends a role. [AuthRepository.register] has no role
/// parameter, and the backend always creates a borrower.
class RegisterController extends ChangeNotifier {
  RegisterController(this._repo);

  static const studentIdLength = 10;
  static const minPasswordLength = 8;

  final AuthRepository _repo;

  bool _busy = false;
  String? _error;
  bool _disposed = false;

  bool get busy => _busy;
  String? get error => _error;

  static String? validateStudentId(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'กรุณากรอกรหัสนักศึกษา';
    if (!RegExp(r'^\d+$').hasMatch(s)) return 'รหัสนักศึกษาต้องเป็นตัวเลข';
    if (s.length != studentIdLength) {
      return 'รหัสนักศึกษาต้องมี $studentIdLength หลัก';
    }
    return null;
  }

  static String? validateFullName(String? v) =>
      (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อ-นามสกุล' : null;

  static String? validatePassword(String? v) =>
      (v == null || v.length < minPasswordLength)
          ? 'รหัสผ่านต้องมีอย่างน้อย $minPasswordLength ตัวอักษร'
          : null;

  static String? validateConfirm(String? password, String? confirm) =>
      password != confirm ? 'รหัสผ่านไม่ตรงกัน' : null;

  /// Returns the new (already signed-in) user, or null when it failed.
  Future<AppUser?> submit({
    required String username,
    required String fullName,
    required String password,
    required String confirm,
  }) async {
    if (_busy) return null;

    final invalid = validateStudentId(username) ??
        validateFullName(fullName) ??
        validatePassword(password) ??
        validateConfirm(password, confirm);
    if (invalid != null) {
      _error = invalid;
      _notify();
      return null;
    }

    _busy = true;
    _error = null;
    _notify();
    try {
      return await _repo.register(
        username: username.trim(),
        fullName: fullName.trim(),
        password: password,
      );
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

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
