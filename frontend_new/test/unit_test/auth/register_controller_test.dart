import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/features/auth/register_controller.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeAuthRepository repo;
  late RegisterController c;

  setUp(() {
    repo = FakeAuthRepository();
    c = RegisterController(repo);
  });

  tearDown(() => c.dispose());

  Future<Object?> submit({
    String username = '6731500002',
    String fullName = 'มาลี รักเรียน',
    String password = 'secret123',
    String? confirm,
  }) =>
      c.submit(
        username: username,
        fullName: fullName,
        password: password,
        confirm: confirm ?? password,
      );

  group('validators', () {
    test('student id: required, digits only, exactly 10 digits', () {
      expect(RegisterController.validateStudentId(''), 'กรุณากรอกรหัสนักศึกษา');
      expect(RegisterController.validateStudentId('67315010ab'), 'รหัสนักศึกษาต้องเป็นตัวเลข');
      expect(RegisterController.validateStudentId('673150108'), 'รหัสนักศึกษาต้องมี 10 หลัก');
      expect(RegisterController.validateStudentId('67315010871'), 'รหัสนักศึกษาต้องมี 10 หลัก');
      expect(RegisterController.validateStudentId('6731501087'), isNull);
      expect(RegisterController.validateStudentId(' 6731501087 '), isNull);
    });

    test('full name is required', () {
      expect(RegisterController.validateFullName(null), 'กรุณากรอกชื่อ-นามสกุล');
      expect(RegisterController.validateFullName('  '), 'กรุณากรอกชื่อ-นามสกุล');
      expect(RegisterController.validateFullName('มาลี รักเรียน'), isNull);
    });

    test('password needs at least 8 characters', () {
      const message = 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
      expect(RegisterController.validatePassword(null), message);
      expect(RegisterController.validatePassword('1234567'), message);
      expect(RegisterController.validatePassword('12345678'), isNull);
    });

    test('confirm must match the password', () {
      expect(RegisterController.validateConfirm('secret123', 'secret124'), 'รหัสผ่านไม่ตรงกัน');
      expect(RegisterController.validateConfirm('secret123', 'secret123'), isNull);
    });
  });

  group('submit', () {
    test('sends trimmed username and name, and the raw password', () async {
      final user = await submit(
        username: ' 6731500002 ',
        fullName: '  มาลี รักเรียน ',
        password: ' secret 123 ',
      );

      expect(user, same(repo.user));
      final call = repo.registerCalls.single;
      expect(call.username, '6731500002');
      expect(call.fullName, 'มาลี รักเรียน');
      expect(call.password, ' secret 123 ');
      expect(c.error, isNull);
      expect(c.busy, isFalse);
    });

    test('each invalid field blocks the request with its own message', () async {
      final cases = <String, Future<Object?> Function()>{
        'กรุณากรอกรหัสนักศึกษา': () => submit(username: ''),
        'รหัสนักศึกษาต้องมี 10 หลัก': () => submit(username: '123'),
        'กรุณากรอกชื่อ-นามสกุล': () => submit(fullName: ' '),
        'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร': () => submit(password: 'short'),
        'รหัสผ่านไม่ตรงกัน': () => submit(confirm: 'different'),
      };

      for (final entry in cases.entries) {
        expect(await entry.value(), isNull, reason: entry.key);
        expect(c.error, entry.key);
      }
      expect(repo.registerCalls, isEmpty);
    });

    test('shows the server message when the student id is taken', () async {
      repo.error = const ApiException(
        'รหัสนักศึกษานี้ถูกใช้งานแล้ว',
        code: 'USERNAME_TAKEN',
        status: 409,
      );

      expect(await submit(), isNull);
      expect(c.error, 'รหัสนักศึกษานี้ถูกใช้งานแล้ว');
      expect(c.busy, isFalse);
    });

    test('shows a generic message for unexpected errors', () async {
      repo.error = StateError('boom');

      expect(await submit(), isNull);
      expect(c.error, 'เชื่อมต่อไม่สำเร็จ กรุณาลองอีกครั้ง');
    });

    test('is busy while the request is in flight and ignores double taps', () async {
      repo.gate = Completer<void>();

      final first = submit();
      expect(c.busy, isTrue);
      expect(await submit(), isNull);
      expect(repo.registerCalls, hasLength(1));

      repo.gate!.complete();
      expect(await first, same(repo.user));
      expect(c.busy, isFalse);
    });

    test('finishing after dispose does not throw', () async {
      final local = RegisterController(repo);
      repo.gate = Completer<void>();

      final pending = local.submit(
        username: '6731500002',
        fullName: 'มาลี รักเรียน',
        password: 'secret123',
        confirm: 'secret123',
      );
      local.dispose();
      repo.gate!.complete();

      await expectLater(pending, completes);
    });
  });
}
