import 'dart:async';

import 'package:frontend/core/api_client.dart';
import 'package:frontend/features/auth/login_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeAuthRepository repo;
  late LoginController c;

  setUp(() {
    repo = FakeAuthRepository();
    c = LoginController(repo);
  });

  tearDown(() => c.dispose());

  group('validators', () {
    test('username is required', () {
      expect(LoginController.validateUsername(null), 'กรุณากรอกรหัสนักศึกษา');
      expect(LoginController.validateUsername('   '), 'กรุณากรอกรหัสนักศึกษา');
      expect(LoginController.validateUsername('6731501087'), isNull);
      expect(LoginController.validateUsername('admin'), isNull);
    });

    test('password is required', () {
      expect(LoginController.validatePassword(null), 'กรุณากรอกรหัสผ่าน');
      expect(LoginController.validatePassword(''), 'กรุณากรอกรหัสผ่าน');
      expect(LoginController.validatePassword('x'), isNull);
    });
  });

  group('submit', () {
    test('returns the user and trims the username only', () async {
      final user = await c.submit(username: '  6731501087 ', password: ' pw ');

      expect(user, same(repo.user));
      expect(repo.loginCalls.single.username, '6731501087');
      expect(repo.loginCalls.single.password, ' pw '); // passwords are never trimmed
      expect(c.error, isNull);
      expect(c.busy, isFalse);
    });

    test('is busy while the request is in flight', () async {
      repo.gate = Completer<void>();

      final pending = c.submit(username: '6731501087', password: 'secret123');
      expect(c.busy, isTrue);

      repo.gate!.complete();
      await pending;
      expect(c.busy, isFalse);
    });

    test('notifies listeners when it starts and when it finishes', () async {
      var notifications = 0;
      c.addListener(() => notifications++);

      await c.submit(username: '6731501087', password: 'secret123');

      expect(notifications, 2);
    });

    test('shows the server message on an API error and returns null', () async {
      repo.error = const ApiException(
        'รหัสนักศึกษาหรือรหัสผ่านไม่ถูกต้อง',
        code: 'INVALID_CREDENTIALS',
        status: 401,
      );

      final user = await c.submit(username: '6731501087', password: 'wrong-pass');

      expect(user, isNull);
      expect(c.error, 'รหัสนักศึกษาหรือรหัสผ่านไม่ถูกต้อง');
      expect(c.busy, isFalse);
    });

    test('shows a generic message for unexpected errors', () async {
      repo.error = StateError('boom');

      final user = await c.submit(username: '6731501087', password: 'secret123');

      expect(user, isNull);
      expect(c.error, 'เชื่อมต่อไม่สำเร็จ กรุณาลองอีกครั้ง');
    });

    test('empty username or password never reaches the repository', () async {
      expect(await c.submit(username: '  ', password: 'secret123'), isNull);
      expect(c.error, 'กรุณากรอกรหัสนักศึกษา');

      expect(await c.submit(username: '6731501087', password: ''), isNull);
      expect(c.error, 'กรุณากรอกรหัสผ่าน');

      expect(repo.loginCalls, isEmpty);
    });

    test('ignores a second submit while one is running', () async {
      repo.gate = Completer<void>();

      final first = c.submit(username: '6731501087', password: 'secret123');
      final second = await c.submit(username: '6731501087', password: 'secret123');

      expect(second, isNull);
      expect(repo.loginCalls, hasLength(1));

      repo.gate!.complete();
      expect(await first, same(repo.user));
    });

    test('a successful retry clears the previous error', () async {
      repo.error = const ApiException('ผิดพลาด');
      await c.submit(username: '6731501087', password: 'secret123');
      expect(c.error, isNotNull);

      repo.error = null;
      final user = await c.submit(username: '6731501087', password: 'secret123');

      expect(user, same(repo.user));
      expect(c.error, isNull);
    });

    test('clearError removes the message', () async {
      repo.error = const ApiException('ผิดพลาด');
      await c.submit(username: '6731501087', password: 'secret123');

      c.clearError();

      expect(c.error, isNull);
    });

    test('finishing after dispose does not throw', () async {
      final local = LoginController(repo);
      repo.gate = Completer<void>();

      final pending = local.submit(username: '6731501087', password: 'secret123');
      local.dispose(); // e.g. the page was replaced after navigation
      repo.gate!.complete();

      await expectLater(pending, completes);
    });
  });
}
