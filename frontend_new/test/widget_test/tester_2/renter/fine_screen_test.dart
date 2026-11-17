import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/payment/payment_models.dart';
import 'package:frontend/features/payment/fine_screen.dart';
import 'package:frontend/core/models.dart';



/// Widget test ของหน้า "ค่าปรับและมัดจำ"
/// ตัวเลขที่ใช้ตรวจ ตรงกับตัวอย่างคำนวณในเอกสาร API Spec หัวข้อ 7
/// (ค่าปรับหักจากมัดจำก่อน ส่วนเกินมัดจำผู้เช่าจ่ายเป็นเงินสดที่ชมรม)

const _camera = Equipment(
  id: 1,
  assetCode: 'CAM-001',
  name: 'กล้อง DSLR',
  categoryId: 1,
  categoryName: 'กล้อง',
  status: EquipmentStatus.available,
);

/// ใบที่คืนแล้ว กำหนดคืน 22 พ.ย. 2026
/// [returnedOn] = วันที่คืนจริง (เกิน 22 = คืนช้า วันละ 30 บาท)
/// [fine] = ค่าปรับรวมที่ backend บันทึก (คืนช้า + ชดเชย) เก็บไว้ที่ชิ้นแรก
BorrowRequest _returned({
  required double deposit,
  required double fine,
  required DateTime returnedOn,
  FineStatus fineStatus = FineStatus.none,
}) {
  return BorrowRequest(
    id: 12,
    purpose: 'ถ่ายกิจกรรม',
    startDate: DateTime(2026, 11, 20),
    endDate: DateTime(2026, 11, 22),
    actualReturnDate: returnedOn,
    status: RequestStatus.returned,
    paymentStatus: PaymentStatus.paid,
    fineStatus: fineStatus,
    items: [
      BorrowItem(
        equipment: _camera,
        pricePerDay: 150,
        deposit: deposit,
        fineAmount: fine,
        conditionAfter: fine > 0 ? 'damaged' : 'good',
      ),
    ],
  );
}

Future<void> _show(WidgetTester tester, BorrowRequest request) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: FineScreen(request: request)));
}

void main() {
  group('FineScreen ค่าปรับไม่เกินมัดจำ', () {
    // มัดจำ 1000 คืนช้า 2 วัน (60) ไม่มีชดเชย => คืนมัดจำ 940
    testWidgets('แสดง "คืนมัดจำให้คุณ" และยอดที่คืน', (tester) async {
      await _show(
        tester,
        _returned(deposit: 1000, fine: 60, returnedOn: DateTime(2026, 11, 24)),
      );

      expect(find.text('ค่าปรับและมัดจำ'), findsOneWidget);
      expect(find.text('คืนมัดจำให้คุณ'), findsOneWidget);
      // ยอดคืน 940 อยู่ 2 ที่: กล่องสรุปด้านบน และบรรทัด "มัดจำที่คืนให้"
      expect(find.text('฿940.00'), findsNWidgets(2));
      expect(find.text('ค่าปรับ ฿60.00 หักจากมัดจำแล้ว'), findsOneWidget);
    });

    testWidgets('แสดงวิธีคำนวณ ค่าปรับคืนช้า = วัน × อัตรา', (tester) async {
      await _show(
        tester,
        _returned(deposit: 1000, fine: 60, returnedOn: DateTime(2026, 11, 24)),
      );

      expect(find.text('เงินมัดจำที่จ่ายไว้'), findsOneWidget);
      expect(find.text('฿1000.00'), findsOneWidget);
      expect(find.text('ค่าปรับคืนช้า (2 วัน × 30 บาท)'), findsOneWidget);
      expect(find.text('- ฿60.00'), findsOneWidget);
    });

    testWidgets('ไม่ต้องจ่ายเพิ่ม: ไม่มีขั้นตอนจ่ายเงินสดและไม่มีป้ายสถานะจ่าย', (tester) async {
      await _show(
        tester,
        _returned(deposit: 1000, fine: 60, returnedOn: DateTime(2026, 11, 24)),
      );

      expect(find.text('ต้องจ่ายเพิ่ม'), findsNothing);
      expect(find.text('วิธีชำระส่วนที่เกิน (เงินสดที่ชมรม)'), findsNothing);
      expect(find.text('ยังไม่จ่าย'), findsNothing);
    });

    testWidgets('คืนตรงเวลา ไม่มีค่าปรับ: ได้มัดจำคืนเต็มจำนวน', (tester) async {
      await _show(
        tester,
        _returned(deposit: 1000, fine: 0, returnedOn: DateTime(2026, 11, 22)),
      );

      expect(find.text('คืนมัดจำให้คุณ'), findsOneWidget);
      expect(find.text('฿1000.00'), findsNWidgets(3)); // กล่องสรุป + มัดจำที่จ่ายไว้ + มัดจำที่คืนให้
      expect(find.text('รายการที่ถูกปรับ'), findsNothing);
    });
  });

  group('FineScreen ค่าปรับเกินมัดจำ', () {
    // มัดจำ 300 คืนช้า 1 วัน (30) + ชดเชยชำรุด 670 = ปรับรวม 700 => หักมัดจำหมด ต้องจ่ายเพิ่ม 400
    testWidgets('แสดง "ต้องจ่ายเพิ่ม" พร้อมยอดส่วนเกินและป้าย "ยังไม่จ่าย"', (tester) async {
      await _show(
        tester,
        _returned(
          deposit: 300,
          fine: 700,
          returnedOn: DateTime(2026, 11, 23),
          fineStatus: FineStatus.unpaid,
        ),
      );

      // "ต้องจ่ายเพิ่ม" อยู่ 2 ที่: หัวกล่องสรุป และบรรทัดในวิธีคำนวณ
      expect(find.text('ต้องจ่ายเพิ่ม'), findsNWidgets(2));
      expect(find.text('฿400.00'), findsNWidgets(2));
      expect(find.text('ยังไม่จ่าย'), findsOneWidget);
      expect(find.text('ค่าปรับมากกว่ามัดจำ จึงไม่มีมัดจำคืน และต้องจ่ายส่วนที่เกิน'), findsOneWidget);
      expect(find.text('คืนมัดจำให้คุณ'), findsNothing);
    });

    testWidgets('แยกบรรทัดค่าปรับคืนช้ากับค่าชดเชยชำรุด', (tester) async {
      await _show(
        tester,
        _returned(
          deposit: 300,
          fine: 700,
          returnedOn: DateTime(2026, 11, 23),
          fineStatus: FineStatus.unpaid,
        ),
      );

      expect(find.text('ค่าปรับคืนช้า (1 วัน × 30 บาท)'), findsOneWidget);
      expect(find.text('- ฿30.00'), findsOneWidget);
      expect(find.text('ค่าชดเชยชำรุด / สูญหาย'), findsOneWidget);
      expect(find.text('- ฿670.00'), findsOneWidget);
      expect(find.text('หักจากมัดจำ'), findsOneWidget);
      expect(find.text('฿300.00'), findsNWidgets(2)); // มัดจำที่จ่ายไว้ + หักจากมัดจำ
    });

    testWidgets('แสดงรายการอุปกรณ์ที่ถูกปรับ และขั้นตอนจ่ายเงินสดที่ชมรม', (tester) async {
      await _show(
        tester,
        _returned(
          deposit: 300,
          fine: 700,
          returnedOn: DateTime(2026, 11, 23),
          fineStatus: FineStatus.unpaid,
        ),
      );

      expect(find.text('รายการที่ถูกปรับ'), findsOneWidget);
      expect(find.text('กล้อง DSLR (CAM-001)'), findsOneWidget);
      expect(find.text('วิธีชำระส่วนที่เกิน (เงินสดที่ชมรม)'), findsOneWidget);
      expect(find.textContaining('แจ้งรหัสนักศึกษา'), findsOneWidget);
    });

    testWidgets('จ่ายส่วนเกินแล้ว: แสดง "จ่ายแล้ว" และซ่อนขั้นตอนจ่ายเงิน', (tester) async {
      await _show(
        tester,
        _returned(
          deposit: 300,
          fine: 700,
          returnedOn: DateTime(2026, 11, 23),
          fineStatus: FineStatus.paid,
        ),
      );

      expect(find.text('จ่ายแล้ว'), findsOneWidget);
      expect(find.text('ยังไม่จ่าย'), findsNothing);
      expect(find.text('วิธีชำระส่วนที่เกิน (เงินสดที่ชมรม)'), findsNothing);
    });
  });

  testWidgets('ปุ่ม "กลับไปรายการของฉัน" ปิดหน้านี้', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => FineScreen(
                request: _returned(
                  deposit: 1000,
                  fine: 60,
                  returnedOn: DateTime(2026, 11, 24),
                ),
              ),
            )),
            child: const Text('เปิดหน้าค่าปรับ'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('เปิดหน้าค่าปรับ'));
    await tester.pumpAndSettle();
    expect(find.text('ค่าปรับและมัดจำ'), findsOneWidget);

    await tester.tap(find.text('กลับไปรายการของฉัน'));
    await tester.pumpAndSettle();
    expect(find.text('ค่าปรับและมัดจำ'), findsNothing);
    expect(find.text('เปิดหน้าค่าปรับ'), findsOneWidget);
  });
}
