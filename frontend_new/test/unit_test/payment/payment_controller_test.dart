import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/payment/payment_controller.dart';
import 'package:frontend/features/payment/payment_models.dart';

/// ตัวเลือกรูปปลอม ใช้แทนแกลเลอรีจริงในเทสต์
class FakePicker implements SlipPicker {
  FakePicker(this.result, {this.error});
  final PickedSlip? result;
  final Object? error;

  @override
  Future<PickedSlip?> pick() async {
    if (error != null) throw error!;
    return result;
  }
}

PickedSlip _png({int size = 1000}) =>
    PickedSlip(name: 'slip.png', bytes: Uint8List(size), mimeType: 'image/png');

BorrowRequest _approved({DateTime? dueAt}) => BorrowRequest(
      id: 900,
      purpose: 'ทดสอบ',
      startDate: DateTime(2027, 1, 10),
      endDate: DateTime(2027, 1, 11),
      status: RequestStatus.approved,
      paymentDueAt: dueAt,
      items: [
        BorrowItem(
          equipment: const Equipment(
            id: 9100,
            assetCode: 'TEST-9100',
            name: 'ไมค์ทดสอบ',
            categoryId: 2,
            categoryName: 'เครื่องเสียง',
            status: EquipmentStatus.available,
            pricePerDay: 100,
            deposit: 500,
          ),
        ),
      ],
      borrowerId: 'user123',
    );

PaymentController _controller(
  BorrowRequest r,
  SlipPicker picker, {
  DateTime Function()? now,
  Future<void> Function(PickedSlip slip)? submitSlip,
}) =>
    PaymentController(
      request: r,
      picker: picker,
      now: now,
      submitSlip: submitSlip ?? (_) async {},
    );

void main() {
  group('เลือกสลิป', () {
    test('รูป PNG ปกติ = ผ่าน และพร้อมส่ง', () async {
      final c = _controller(_approved(), FakePicker(_png()));
      expect(c.canSend, isFalse); // ยังไม่ได้เลือก
      final error = await c.pickSlip();
      expect(error, isNull);
      expect(c.hasSlip, isTrue);
      expect(c.slipName, 'slip.png');
      expect(c.canSend, isTrue);
    });

    test('ไฟล์ที่ไม่ใช่รูป (PDF) = ไม่ผ่าน ไม่เก็บไฟล์', () async {
      final pdf = PickedSlip(name: 'doc.pdf', bytes: Uint8List(100), mimeType: 'application/pdf');
      final c = _controller(_approved(), FakePicker(pdf));
      final error = await c.pickSlip();
      expect(error, isNotNull);
      expect(c.hasSlip, isFalse);
    });

    test('ไฟล์ใหญ่เกิน 5 MB = ไม่ผ่าน', () async {
      final c = _controller(_approved(), FakePicker(_png(size: 5 * 1024 * 1024 + 1)));
      final error = await c.pickSlip();
      expect(error, 'ไฟล์ใหญ่เกิน 5 MB');
      expect(c.hasSlip, isFalse);
    });

    test('ผู้ใช้ปิดหน้าเลือกรูปเฉยๆ (ได้ null) = ไม่มี error ไม่มีไฟล์', () async {
      final c = _controller(_approved(), FakePicker(null));
      expect(await c.pickSlip(), isNull);
      expect(c.hasSlip, isFalse);
    });

    test('เปิดแกลเลอรีไม่ได้ (เกิด exception) = ได้ข้อความ error ไม่พัง', () async {
      final c = _controller(_approved(), FakePicker(null, error: Exception('no permission')));
      final error = await c.pickSlip();
      expect(error, 'เปิดแกลเลอรีไม่ได้ กรุณาลองอีกครั้ง');
      expect(c.hasSlip, isFalse);
    });
  });

  group('ส่งสลิป', () {
    test('ส่งไฟล์ที่เลือกไปยังตัวส่ง backend', () async {
      final submitted = <PickedSlip>[];
      final c = _controller(
        _approved(),
        FakePicker(_png()),
        submitSlip: (slip) async => submitted.add(slip),
      );
      await c.pickSlip();

      expect(await c.send(), isTrue);
      expect(submitted.single.name, 'slip.png');
      expect(submitted.single.mimeType, 'image/png');
      expect(submitted.single.bytes, isNotEmpty);
    });

    test('ยังไม่เลือกรูป = ส่งไม่ได้', () async {
      final c = _controller(_approved(), FakePicker(_png()));
      expect(await c.send(), isFalse);
    });

    test('ขณะส่งอยู่ ป้องกันการส่งซ้ำ', () async {
      final gate = Completer<void>();
      final c = _controller(
        _approved(),
        FakePicker(_png()),
        submitSlip: (_) => gate.future,
      );
      await c.pickSlip();
      final pendingSend = c.send();
      expect(c.isSending, isTrue);
      expect(await c.send(), isFalse);
      gate.complete();
      expect(await pendingSend, isTrue);
      expect(c.isSending, isFalse);
    });

    test('ใบยังไม่อนุมัติ = ส่งไม่ได้', () async {
      final r = _approved()..status = RequestStatus.pending;
      final c = _controller(r, FakePicker(_png()));
      await c.pickSlip();
      expect(c.canSend, isFalse);
      expect(await c.send(), isFalse);
    });

    test('เลยกำหนดชำระแล้ว = ส่งไม่ได้', () async {
      final r = _approved(dueAt: DateTime.now().subtract(const Duration(minutes: 1)));
      final c = _controller(r, FakePicker(_png()));
      await c.pickSlip();
      expect(c.canSend, isFalse);
      expect(await c.send(), isFalse);
    });
  });

  group('เวลาที่เหลือ', () {
    test('เหลือ 5 ชม. 20 นาที', () {
      final due = DateTime.now().add(const Duration(days: 2));
      final r = _approved(dueAt: due);
      final c = _controller(
        r,
        FakePicker(null),
        now: () => due.subtract(const Duration(hours: 5, minutes: 20)),
      );
      expect(c.timeLeftLabel, '5 ชม. 20 นาที');
    });

    test('ไม่มีกำหนดชำระ = null', () {
      final c = _controller(_approved(), FakePicker(null));
      expect(c.timeLeftLabel, isNull);
    });

    test('จ่ายไม่ได้แล้ว (รอตรวจ) = ไม่แสดงเวลาที่เหลือ', () {
      final r = _approved(dueAt: DateTime.now().add(const Duration(hours: 3)))
        ..paymentStatus = PaymentStatus.pendingReview;
      final c = _controller(r, FakePicker(null));
      expect(c.timeLeftLabel, isNull);
    });
  });
}
