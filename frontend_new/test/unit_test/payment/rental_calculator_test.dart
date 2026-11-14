import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/payment/rental_calculator.dart';

void main() {
  group('rentalDays', () {
    test('วันเดียว = 1 วัน', () {
      expect(rentalDays(DateTime(2026, 11, 10), DateTime(2026, 11, 10)), 1);
    });

    test('นับวันเริ่มและวันคืนรวมกัน (5 ถึง 7 = 3 วัน)', () {
      expect(rentalDays(DateTime(2026, 11, 5), DateTime(2026, 11, 7)), 3);
    });

    test('ไม่สนใจเวลาในวัน', () {
      expect(
        rentalDays(DateTime(2026, 11, 5, 23, 30), DateTime(2026, 11, 6, 0, 10)),
        2,
      );
    });

    test('วันคืนก่อนวันเริ่ม = 0', () {
      expect(rentalDays(DateTime(2026, 11, 10), DateTime(2026, 11, 5)), 0);
    });
  });

  group('rentalFee / totalDeposit', () {
    test('กล้อง 150 + ขาตั้ง 40 เช่า 3 วัน = 570', () {
      expect(rentalFee(pricesPerDay: [150, 40], days: 3), 570);
    });

    test('0 วัน หรือไม่มีของ = 0', () {
      expect(rentalFee(pricesPerDay: [150], days: 0), 0);
      expect(rentalFee(pricesPerDay: [], days: 3), 0);
    });

    test('มัดจำรวมทุกชิ้น', () {
      expect(totalDeposit([1000, 200]), 1200);
      expect(totalDeposit([]), 0);
    });
  });

  group('lateFine', () {
    test('คืนช้า 2 วัน × 30 = 60', () {
      expect(lateFine(lateDays: 2, ratePerDay: 30), 60);
    });

    test('ไม่ช้า = 0', () {
      expect(lateFine(lateDays: 0, ratePerDay: 30), 0);
      expect(lateFine(lateDays: -1, ratePerDay: 30), 0);
    });
  });

  group('settleDeposit', () {
    test('ไม่มีค่าปรับ คืนมัดจำเต็ม', () {
      final s = settleDeposit(deposit: 500, totalFine: 0);
      expect(s, const DepositSettlement(deducted: 0, refund: 500, extraDue: 0));
    });

    test('ค่าปรับน้อยกว่ามัดจำ หักแล้วคืนส่วนที่เหลือ (500 - 60 = 440)', () {
      final s = settleDeposit(deposit: 500, totalFine: 60);
      expect(s.deducted, 60);
      expect(s.refund, 440);
      expect(s.extraDue, 0);
    });

    test('ค่าปรับเท่ามัดจำพอดี ไม่คืนและไม่ต้องจ่ายเพิ่ม', () {
      final s = settleDeposit(deposit: 500, totalFine: 500);
      expect(s, const DepositSettlement(deducted: 500, refund: 0, extraDue: 0));
    });

    test('ค่าปรับเกินมัดจำ ผู้เช่าจ่ายเพิ่มส่วนที่เกิน (900 - 500 = 400)', () {
      final s = settleDeposit(deposit: 500, totalFine: 900);
      expect(s.deducted, 500);
      expect(s.refund, 0);
      expect(s.extraDue, 400);
    });

    test('ค่าติดลบถือเป็น 0', () {
      final s = settleDeposit(deposit: -10, totalFine: -5);
      expect(s, const DepositSettlement(deducted: 0, refund: 0, extraDue: 0));
    });
  });

  group('timeLeft / timeLeftText', () {
    final now = DateTime(2026, 11, 12, 9, 0);

    test('เหลือเวลา 5 ชม. 20 นาที', () {
      final left = timeLeft(DateTime(2026, 11, 12, 14, 20), now);
      expect(left, const Duration(hours: 5, minutes: 20));
      expect(timeLeftText(left), '5 ชม. 20 นาที');
    });

    test('เหลือไม่ถึงชั่วโมง แสดงเป็นนาที', () {
      expect(timeLeftText(const Duration(minutes: 45)), '45 นาที');
      expect(timeLeftText(const Duration(seconds: 20)), '1 นาที');
    });

    test('เลยกำหนดแล้ว = 0 และข้อความหมดเวลา', () {
      final left = timeLeft(DateTime(2026, 11, 12, 8, 0), now);
      expect(left, Duration.zero);
      expect(timeLeftText(left), 'หมดเวลาแล้ว');
    });
  });

  test('ตัวอย่างครบวงจร: กล้อง 100/วัน มัดจำ 500 เช่า 3 วัน คืนช้า 2 วัน', () {
    final days = rentalDays(DateTime(2026, 11, 1), DateTime(2026, 11, 3));
    final fee = rentalFee(pricesPerDay: [100], days: days);
    final deposit = totalDeposit([500]);
    expect(fee + deposit, 800); // ยอดที่จ่ายตอนเช่า

    final fine = lateFine(lateDays: 2, ratePerDay: 30);
    final s = settleDeposit(deposit: deposit, totalFine: fine);
    expect(s.refund, 440); // คืนมัดจำ
  });
}
