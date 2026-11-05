import 'mock/app_store.dart';
import 'models.dart';

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

/// Replace the Mock* classes with HTTP implementations when the backend is ready.
/// Password hashing (Argon2id) must happen on the server: the app only sends
/// the plain password over HTTPS.
abstract class AuthRepository {
  Future<AppUser> login({required String username, required String password});

  Future<AppUser> register({
    required String username,
    required String fullName,
    required String password,
  });
}

abstract class EquipmentRepository {
  Future<List<Category>> fetchCategories();
  Future<List<Equipment>> fetchEquipment();
}

// ---------------------------------------------------------------------------
// Mock implementations (in-memory) for developing the UI without a backend
// ---------------------------------------------------------------------------

class _Account {
  _Account(this.user, this.password);
  final AppUser user;
  final String password;
}

class MockAuthRepository implements AuthRepository {
  int _nextId = 3;

  final Map<String, _Account> _accounts = {
    'user123': _Account(
      const AppUser(
        id: 1,
        username: 'user123',
        fullName: 'สมชาย ใจดี',
        role: UserRole.borrower,
      ),
      '1234',
    ),
    'admin123': _Account(
      const AppUser(
        id: 2,
        username: 'admin123',
        fullName: 'ผู้ดูแลระบบ',
        role: UserRole.admin,
      ),
      '1234',
    ),
  };

  @override
  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    final account = _accounts[username];
    if (account == null || account.password != password) {
      throw const AuthException('รหัสนักศึกษาหรือรหัสผ่านไม่ถูกต้อง');
    }
    return account.user;
  }

  @override
  Future<AppUser> register({
    required String username,
    required String fullName,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (_accounts.containsKey(username)) {
      throw const AuthException('รหัสนักศึกษานี้ถูกใช้งานแล้ว');
    }
    final user = AppUser(
      id: _nextId++,
      username: username,
      fullName: fullName,
      role: UserRole.borrower,
    );
    _accounts[username] = _Account(user, password);
    return user;
  }
}

class MockEquipmentRepository implements EquipmentRepository {
  static const _camera = Category(id: 1, name: 'กล้อง');
  static const _audio = Category(id: 2, name: 'เครื่องเสียง');
  static const _radio = Category(id: 3, name: 'วิทยุสื่อสาร');
  static const _lighting = Category(id: 4, name: 'แสงสว่าง');

  @override
  Future<List<Category>> fetchCategories() async {
    await Future.delayed(const Duration(milliseconds: 200));
    return const [_camera, _audio, _radio, _lighting];
  }

  @override
  Future<List<Equipment>> fetchEquipment() async {
    await Future.delayed(const Duration(milliseconds: 400));
    // ข้อมูลอุปกรณ์อยู่ที่ AppStore ที่เดียว (ใช้ร่วมกับหน้าแอดมิน)
    return AppStore.instance.catalog();
  }
}
