import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/renter/utils/slip_utils.dart';

void main() {
  group('isAllowedSlipFile', () {
    test('รับ jpg jpeg png (ตัวพิมพ์ใหญ่เล็กก็ได้)', () {
      expect(isAllowedSlipFile('slip.jpg'), isTrue);
      expect(isAllowedSlipFile('slip.JPEG'), isTrue);
      expect(isAllowedSlipFile('slip.png'), isTrue);
    });

    test('ไม่รับไฟล์ที่ไม่ใช่รูป', () {
      expect(isAllowedSlipFile('slip.pdf'), isFalse);
      expect(isAllowedSlipFile('virus.exe'), isFalse);
      expect(isAllowedSlipFile('slip'), isFalse);
    });

    test('ใช้ชนิดไฟล์ (mime) ตัดสินได้เมื่อชื่อไม่มีนามสกุล', () {
      expect(isAllowedSlipFile('image_picker_123', mimeType: 'image/png'), isTrue);
      expect(isAllowedSlipFile('image_picker_123', mimeType: 'application/pdf'), isFalse);
    });
  });

  group('slipError', () {
    test('ไฟล์ปกติผ่าน (null)', () {
      expect(slipError('a.png', 1000), isNull);
    });

    test('เกิน 5 MB ไม่ผ่าน', () {
      expect(slipError('a.png', maxSlipBytes + 1), 'ไฟล์ใหญ่เกิน 5 MB');
      expect(slipError('a.png', maxSlipBytes), isNull); // พอดี 5 MB ผ่าน
    });

    test('ชนิดไม่ถูกต้อง และไฟล์ว่าง ไม่ผ่าน', () {
      expect(slipError('a.pdf', 1000), 'รับเฉพาะรูป JPG หรือ PNG');
      expect(slipError('a.png', 0), 'ไฟล์ว่างเปล่า');
    });
  });
}
