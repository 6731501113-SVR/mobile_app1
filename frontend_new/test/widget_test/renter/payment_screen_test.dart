import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/features/renter/controllers/payment_controller.dart';
import 'package:frontend/features/renter/models.dart';
import 'package:frontend/features/renter/models/borrow_request.dart';
import 'package:frontend/features/renter/screens/payment_screen.dart';

/// Widget test ของหน้า "ชำระเงิน"
/// ตรรกะ (เลือกสลิป ตรวจไฟล์ นับเวลา) ทดสอบใน payment_controller_test.dart แล้ว
/// ไฟล์นี้ทดสอบแค่ว่าหน้าจอแสดงผลและตอบสนองการกดถูกต้อง โดยไม่เรียก backend และไม่เปิดแกลเลอรีจริง

/// รูป PNG ขนาด 1x1 ที่ถูกต้อง (Image.memory ต้องการไฟล์รูปจริง)
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _FakePicker implements SlipPicker {
  _FakePicker(this.result);
  PickedSlip? result;
  int calls = 0;

  @override
  Future<PickedSlip?> pick() async {
    calls++;
    return result;
  }
}

const _camera = Equipment(
  id: 1,
  assetCode: 'CAM-001',
  name: 'กล้อง DSLR',
  categoryId: 1,
  categoryName: 'กล้อง',
  status: EquipmentStatus.available,
);

/// เช่า 20–22 พ.ย. 2026 = 3 วัน ราคา 150/วัน มัดจำ 1000
/// ค่าเช่า 450 + มัดจำ 1000 = ต้องชำระ 1450
BorrowRequest _request({
  RequestStatus status = RequestStatus.approved,
  PaymentStatus payment = PaymentStatus.unpaid,
  DateTime? dueAt,
  String? paymentNote,
  String? adminNote,
}) {
  return BorrowRequest(
    id: 12,
    purpose: 'ถ่ายกิจกรรม',
    startDate: DateTime(2026, 11, 20),
    endDate: DateTime(2026, 11, 22),
    status: status,
    paymentStatus: payment,
    paymentDueAt: dueAt ?? DateTime.now().add(const Duration(hours: 5)),
    paymentNote: paymentNote,
    adminNote: adminNote,
    items: [BorrowItem(equipment: _camera, pricePerDay: 150, deposit: 1000)],
  );
}

/// ขยายหน้าจอทดสอบให้สูงพอ ไม่ต้องเลื่อนหาปุ่ม
void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _show(
  WidgetTester tester,
  BorrowRequest request, {
  required Future<void> Function(PickedSlip) onSubmit,
  _FakePicker? picker,
}) async {
  _bigScreen(tester);
  await tester.pumpWidget(MaterialApp(
    home: PaymentScreen(request: request, onSubmitSlip: onSubmit, picker: picker),
  ));
}

/// ปิดหน้าจอให้ Timer ของหน้าชำระเงินถูกยกเลิก ไม่งั้น test จะฟ้องว่ามี Timer ค้าง
Future<void> _close(WidgetTester tester) => tester.pumpWidget(const SizedBox());

Finder _sendButton() => find.widgetWithText(FilledButton, 'ส่งสลิป ฿1450.00');

void main() {
  group('PaymentScreen สรุปยอด', () {
    testWidgets('แสดงค่าเช่า มัดจำ และยอดที่ต้องชำระ', (tester) async {
      await _show(tester, _request(), onSubmit: (_) async {});

      expect(find.text('ชำระเงิน'), findsOneWidget);
      expect(find.text('กล้อง DSLR × 3 วัน'), findsOneWidget);
      // ค่าเช่า 450 ปรากฏ 2 ที่: บรรทัดของชิ้น และบรรทัดค่าเช่ารวม
      expect(find.text('฿450.00'), findsNWidgets(2));
      expect(find.text('฿1000.00'), findsOneWidget);
      expect(find.text('฿1450.00'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('แสดงเวลาที่ต้องชำระภายใน', (tester) async {
      await _show(tester, _request(), onSubmit: (_) async {});

      expect(find.textContaining('ชำระภายใน'), findsOneWidget);
      expect(find.textContaining('ยกเลิกอัตโนมัติ'), findsOneWidget);
      await _close(tester);
    });
  });

  group('PaymentScreen แนบสลิปและส่ง', () {
    testWidgets('ปุ่มส่งสลิปกดไม่ได้จนกว่าจะแนบสลิป', (tester) async {
      await _show(tester, _request(), onSubmit: (_) async {});

      expect(find.text('แนบสลิปการโอน'), findsOneWidget);
      expect(tester.widget<FilledButton>(_sendButton()).onPressed, isNull);
      await _close(tester);
    });

    testWidgets('แนบสลิปแล้วแสดงชื่อไฟล์และปุ่มส่งกดได้', (tester) async {
      final picker =
          _FakePicker(PickedSlip(name: 'slip.png', bytes: _png, mimeType: 'image/png'));
      await _show(tester, _request(), onSubmit: (_) async {}, picker: picker);

      await tester.tap(find.text('แนบสลิปการโอน'));
      await tester.pumpAndSettle();

      expect(picker.calls, 1);
      expect(find.textContaining('แนบแล้ว: slip.png'), findsOneWidget);
      expect(tester.widget<FilledButton>(_sendButton()).onPressed, isNotNull);
      await _close(tester);
    });

    testWidgets('ไฟล์ผิดชนิดขึ้นข้อความเตือนและยังส่งไม่ได้', (tester) async {
      final picker = _FakePicker(
        PickedSlip(name: 'slip.pdf', bytes: _png, mimeType: 'application/pdf'),
      );
      await _show(tester, _request(), onSubmit: (_) async {}, picker: picker);

      await tester.tap(find.text('แนบสลิปการโอน'));
      await tester.pumpAndSettle();

      expect(find.text('รับเฉพาะรูป JPG หรือ PNG'), findsOneWidget);
      expect(find.text('แนบสลิปการโอน'), findsOneWidget); // ยังไม่ถูกแทนด้วยชื่อไฟล์
      expect(tester.widget<FilledButton>(_sendButton()).onPressed, isNull);
      await _close(tester);
    });

    testWidgets('กดส่งสลิป เรียก onSubmitSlip แล้วปิดหน้าพร้อมผลลัพธ์ true', (tester) async {
      _bigScreen(tester);
      final sent = <PickedSlip>[];
      final picker =
          _FakePicker(PickedSlip(name: 'slip.png', bytes: _png, mimeType: 'image/png'));
      bool? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => PaymentScreen(
                    request: _request(),
                    picker: picker,
                    onSubmitSlip: (slip) async => sent.add(slip),
                  ),
                ));
              },
              child: const Text('เปิดหน้าชำระเงิน'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('เปิดหน้าชำระเงิน'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('แนบสลิปการโอน'));
      await tester.pumpAndSettle();
      await tester.tap(_sendButton());
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      expect(sent.single.name, 'slip.png');
      expect(result, isTrue);
      expect(find.text('ชำระเงิน'), findsNothing); // กลับไปหน้าเดิมแล้ว
      expect(find.text('ส่งสลิปแล้ว รอผู้ดูแลตรวจสอบ'), findsOneWidget);
    });

    testWidgets('backend ตอบ error แสดงข้อความและอยู่หน้าเดิม', (tester) async {
      final picker =
          _FakePicker(PickedSlip(name: 'slip.png', bytes: _png, mimeType: 'image/png'));
      await _show(
        tester,
        _request(),
        picker: picker,
        onSubmit: (_) async => throw const ApiException('ใบนี้หมดเวลาชำระแล้ว'),
      );

      await tester.tap(find.text('แนบสลิปการโอน'));
      await tester.pumpAndSettle();
      await tester.tap(_sendButton());
      await tester.pumpAndSettle();

      expect(find.text('ใบนี้หมดเวลาชำระแล้ว'), findsOneWidget);
      expect(find.text('ชำระเงิน'), findsOneWidget);
      await _close(tester);
    });
  });

  group('PaymentScreen ตามสถานะการชำระ', () {
    testWidgets('สลิปถูกปฏิเสธ: แสดงเหตุผลและให้ส่งใหม่ได้', (tester) async {
      await _show(
        tester,
        _request(payment: PaymentStatus.rejected, paymentNote: 'ยอดไม่ตรง'),
        onSubmit: (_) async {},
      );

      expect(find.textContaining('สลิปครั้งก่อนถูกปฏิเสธ: ยอดไม่ตรง'), findsOneWidget);
      expect(find.text('แนบสลิปการโอน'), findsOneWidget);
      await _close(tester);
    });

    testWidgets('ส่งสลิปแล้วรอตรวจ: ไม่มีช่องแนบสลิป', (tester) async {
      await _show(
        tester,
        _request(payment: PaymentStatus.pendingReview),
        onSubmit: (_) async {},
      );

      expect(find.text('ส่งสลิปแล้ว รอผู้ดูแลตรวจสอบ'), findsOneWidget);
      expect(find.text('แนบสลิปการโอน'), findsNothing);
      expect(find.textContaining('ส่งสลิป ฿'), findsNothing);
      await _close(tester);
    });

    testWidgets('ชำระแล้ว: แสดงข้อความสำเร็จ ไม่มีช่องแนบสลิป', (tester) async {
      await _show(
        tester,
        _request(payment: PaymentStatus.paid),
        onSubmit: (_) async {},
      );

      expect(find.textContaining('ชำระเงินเรียบร้อยแล้ว'), findsOneWidget);
      expect(find.text('แนบสลิปการโอน'), findsNothing);
      await _close(tester);
    });

    testWidgets('ใบถูกยกเลิก: แสดงเหตุผลและไม่มีช่องแนบสลิป', (tester) async {
      await _show(
        tester,
        _request(status: RequestStatus.cancelled, adminNote: 'หมดเวลาชำระเงิน'),
        onSubmit: (_) async {},
      );

      expect(find.text('หมดเวลาชำระเงิน'), findsOneWidget);
      expect(find.text('แนบสลิปการโอน'), findsNothing);
      await _close(tester);
    });

    testWidgets('เลยกำหนดชำระแล้ว: ไม่มีช่องแนบสลิป', (tester) async {
      await _show(
        tester,
        _request(dueAt: DateTime.now().subtract(const Duration(hours: 1))),
        onSubmit: (_) async {},
      );

      expect(find.text('แนบสลิปการโอน'), findsNothing);
      await _close(tester);
    });
  });
}
