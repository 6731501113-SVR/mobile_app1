import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';

void main() {
  group('translateBackendMessage', () {
    test('login and register errors are in Thai with a stable code', () {
      final bad = translateBackendMessage('Invalid username or password.');
      expect(bad.message, 'รหัสนักศึกษาหรือรหัสผ่านไม่ถูกต้อง');
      expect(bad.code, 'INVALID_CREDENTIALS');

      final taken = translateBackendMessage('Username already exists.');
      expect(taken.message, 'รหัสนักศึกษานี้ถูกใช้งานแล้ว');
      expect(taken.code, 'USERNAME_TAKEN');
    });

    test('duplicate asset code / category are not mistaken for a taken username', () {
      expect(
        translateBackendMessage('asset_code already exists').message,
        'รหัสสินทรัพย์นี้มีอยู่แล้ว',
      );
      expect(
        translateBackendMessage('Category already exists').message,
        'มีหมวดหมู่นี้อยู่แล้ว',
      );
    });

    test('booking conflicts carry EQUIPMENT_UNAVAILABLE so the calendar refreshes', () {
      expect(
        translateBackendMessage('Some items are already booked or requested for these dates.')
            .code,
        'EQUIPMENT_UNAVAILABLE',
      );
      expect(translateBackendMessage('Item 3 is not available.').code, 'EQUIPMENT_UNAVAILABLE');
    });

    test('payment rules from the backend', () {
      expect(
        translateBackendMessage('The payment deadline has passed.').code,
        'PAYMENT_EXPIRED',
      );
      expect(translateBackendMessage('This request is already paid.').code, 'ALREADY_PAID');
    });

    test('an unknown message is returned unchanged', () {
      final t = translateBackendMessage('Something new');
      expect(t.message, 'Something new');
      expect(t.code, isNull);
    });
  });
}
