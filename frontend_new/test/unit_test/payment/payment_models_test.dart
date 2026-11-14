import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/payment/payment_models.dart';

Equipment _camera() => const Equipment(
      id: 1,
      assetCode: 'CAM-001',
      name: 'กล้อง Canon EOS M50',
      categoryId: 1,
      categoryName: 'กล้อง',
      status: EquipmentStatus.available,
      pricePerDay: 150,
      deposit: 1000,
    );

Equipment _tripod() => const Equipment(
      id: 6,
      assetCode: 'TRI-002',
      name: 'ขาตั้งกล้อง',
      categoryId: 1,
      categoryName: 'กล้อง',
      status: EquipmentStatus.available,
      pricePerDay: 40,
      deposit: 200,
    );

BorrowRequest _request({RequestStatus status = RequestStatus.approved}) => BorrowRequest(
      id: 7,
      purpose: 'ถ่ายภาพงานรับน้อง',
      startDate: DateTime(2026, 11, 5),
      endDate: DateTime(2026, 11, 7),
      status: status,
      items: [BorrowItem(equipment: _camera()), BorrowItem(equipment: _tripod())],
      borrowerName: 'สมชาย ใจดี',
      borrowerId: 'user123',
    );

void main() {
  group('ยอดเงินของใบเช่า', () {
    test('ค่าเช่า มัดจำ และยอดที่ต้องจ่าย', () {
      final r = _request();
      expect(r.days, 3);
      expect(r.rentalTotal, 570); // (150 + 40) x 3
      expect(r.depositTotal, 1200);
      expect(r.amountDue, 1770);
    });

    test('ราคาที่เก็บไว้ในใบ ไม่เปลี่ยนตามราคาปัจจุบันของอุปกรณ์', () {
      final changed = Equipment(
        id: 1,
        assetCode: 'CAM-001',
        name: 'กล้อง Canon EOS M50',
        categoryId: 1,
        categoryName: 'กล้อง',
        status: EquipmentStatus.available,
        pricePerDay: 999,
        deposit: 9999,
      );
      // ใบที่จองไว้ตอนราคา 150 / มัดจำ 1000 (ส่งค่า snapshot เข้าไป)
      final item = BorrowItem(equipment: changed, pricePerDay: 150, deposit: 1000);
      expect(item.pricePerDay, 150);
      expect(item.deposit, 1000);
      // ถ้าไม่ส่งค่ามา จะใช้ราคาปัจจุบันของอุปกรณ์ตอนสร้างใบ
      expect(BorrowItem(equipment: changed).pricePerDay, 999);
    });
  });

  group('canPay', () {
    test('อนุมัติแล้วและยังไม่จ่าย = จ่ายได้', () {
      expect(_request().canPay, isTrue);
    });

    test('รอตรวจสลิป หรือจ่ายแล้ว = จ่ายไม่ได้', () {
      expect((_request()..paymentStatus = PaymentStatus.pendingReview).canPay, isFalse);
      expect((_request()..paymentStatus = PaymentStatus.paid).canPay, isFalse);
    });

    test('สลิปถูกปฏิเสธ = ส่งใหม่ได้', () {
      expect((_request()..paymentStatus = PaymentStatus.rejected).canPay, isTrue);
    });

    test('ยังไม่อนุมัติ = จ่ายไม่ได้', () {
      expect(_request(status: RequestStatus.pending).canPay, isFalse);
    });
  });

  group('กำหนดชำระ (24 ชม. หลังอนุมัติ)', () {
    final due = DateTime(2026, 11, 12, 14, 0);

    test('ยังไม่ถึงกำหนด = ยังจ่ายได้ ไม่หมดเวลา', () {
      final r = _request()..paymentDueAt = due;
      expect(r.isPaymentOverdueAt(DateTime(2026, 11, 12, 13, 59)), isFalse);
    });

    test('เลยกำหนดและยังไม่จ่าย = หมดเวลา', () {
      final r = _request()..paymentDueAt = due;
      expect(r.isPaymentOverdueAt(DateTime(2026, 11, 12, 14, 1)), isTrue);
    });

    test('สลิปถูกปฏิเสธแล้วเลยกำหนด = หมดเวลาเช่นกัน', () {
      final r = _request()
        ..paymentDueAt = due
        ..paymentStatus = PaymentStatus.rejected;
      expect(r.isPaymentOverdueAt(DateTime(2026, 11, 13)), isTrue);
    });

    test('ส่งสลิปแล้วรอตรวจ หรือจ่ายแล้ว ไม่ถูกนับว่าหมดเวลา', () {
      final waiting = _request()
        ..paymentDueAt = due
        ..paymentStatus = PaymentStatus.pendingReview;
      final paid = _request()
        ..paymentDueAt = due
        ..paymentStatus = PaymentStatus.paid;
      expect(waiting.isPaymentOverdueAt(DateTime(2026, 11, 20)), isFalse);
      expect(paid.isPaymentOverdueAt(DateTime(2026, 11, 20)), isFalse);
    });

    test('ใบที่ยังไม่อนุมัติ ไม่มีกำหนดชำระ', () {
      final r = _request(status: RequestStatus.pending)..paymentDueAt = due;
      expect(r.isPaymentOverdueAt(DateTime(2026, 11, 20)), isFalse);
    });

    test('ไม่มีกำหนดชำระ (null) = ไม่หมดเวลา', () {
      expect(_request().isPaymentOverdueAt(DateTime(2030)), isFalse);
    });

    test('JSON เก็บและอ่านกำหนดชำระได้', () {
      final r = _request()..paymentDueAt = due;
      final back = BorrowRequest.fromJson(r.toJson());
      expect(back.paymentDueAt, due);
    });
  });

  group('JSON', () {
    test('toJson แล้ว fromJson ได้ค่าเดิม', () {
      final r = _request()
        ..paymentStatus = PaymentStatus.pendingReview
        ..slipPath = 'uploads/slip7.jpg';
      final back = BorrowRequest.fromJson(r.toJson());

      expect(back.id, 7);
      expect(back.status, RequestStatus.approved);
      expect(back.paymentStatus, PaymentStatus.pendingReview);
      expect(back.slipPath, 'uploads/slip7.jpg');
      expect(back.startDate, DateTime(2026, 11, 5));
      expect(back.endDate, DateTime(2026, 11, 7));
      expect(back.items.length, 2);
      expect(back.amountDue, r.amountDue);
    });

    test('fromJson รับตัวเลขที่มาเป็นข้อความ (DECIMAL ของ MySQL)', () {
      final e = Equipment.fromJson({
        'id': 1,
        'asset_code': 'CAM-001',
        'name': 'กล้อง',
        'category_id': 1,
        'category_name': 'กล้อง',
        'status': 'available',
        'price_per_day': '150.00',
        'deposit': '1000.00',
      });
      expect(e.pricePerDay, 150);
      expect(e.deposit, 1000);
    });

    test('ไม่มีฟิลด์ราคา = 0 ไม่พัง', () {
      final e = Equipment.fromJson({
        'id': 2,
        'asset_code': 'MIC-003',
        'name': 'ไมค์',
        'category_id': 2,
        'status': 'borrowed',
      });
      expect(e.pricePerDay, 0);
      expect(e.deposit, 0);
      expect(e.status, EquipmentStatus.borrowed);
    });
  });
}
