import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/core/api_client.dart';
import 'package:frontend/features/admin/data/api_repository.dart';
import 'package:frontend/features/admin/screens/delivery_return_screen.dart';

http.Response jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(jsonEncode(body), statusCode,
        headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late int detailStatus;
  late int returnStatus;

  setUp(() {
    requests = [];
    detailStatus = 200;
    returnStatus = 200;

    ApiRepository.client = ApiClient(
      baseUrl: 'http://localhost:3000',
      client: MockClient((request) async {
        requests.add(request);

        if (request.method == 'GET' && request.url.path == '/api/borrows/43') {
          if (detailStatus != 200) {
            return jsonResponse(
              {'message': 'ไม่สามารถโหลดรายละเอียดได้'},
              statusCode: detailStatus,
            );
          }
          return jsonResponse({
            'data': {
              'items': [
                {
                  'equipment_id': 31,
                  'equipment_name': 'กล้องถ่ายรูป',
                  'asset_code': 'CAM-001',
                },
                {
                  'equipment_id': 32,
                  'equipment_name': 'ขาตั้งกล้อง',
                  'asset_code': 'TRI-002',
                }
              ]
            }
          });
        }

        if (request.method == 'PUT' &&
            request.url.path == '/api/borrows/43/return') {
          if (returnStatus != 200) {
            return jsonResponse(
              {'message': 'บันทึกการรับคืนไม่สำเร็จ'},
              statusCode: returnStatus,
            );
          }
          return jsonResponse({
            'data': {
              'late_fine': 30,
              'total_damage_fine': 100,
              'fine_amount': 130,
            }
          });
        }

        return jsonResponse({'message': 'Unexpected request'}, statusCode: 404);
      }),
    )..token = 'test-admin-token';
  });

  tearDown(() {
    ApiRepository.client = null;
  });

  Future<void> openDetail(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: DeliveryReturnScreen(requestId: 43, totalDeposit: 500),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('แสดงรหัสคำขอ เงินมัดจำ และอุปกรณ์ทั้งหมด',
      (tester) async {
    await openDetail(tester);

    expect(find.text('จัดการรับคืนอุปกรณ์'), findsOneWidget);
    expect(find.text('รหัสคำขอยืม: #43'), findsOneWidget);
    expect(find.text('เงินมัดจำทั้งหมด: 500.0 บาท'), findsOneWidget);
    expect(find.text('กล้องถ่ายรูป · CAM-001'), findsOneWidget);
    expect(find.text('ขาตั้งกล้อง · TRI-002'), findsOneWidget);
    expect(find.text('สภาพอุปกรณ์หลังคืน'), findsNWidgets(2));
    expect(find.text('ยืนยันรับคืนและคำนวณเงินมัดจำ'), findsOneWidget);
  });

  testWidgets('เลือกสภาพอุปกรณ์และกรอกค่าปรับได้', (tester) async {
    await openDetail(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ชำรุด').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '100');
    await tester.pump();

    expect(find.text('ค่าปรับความเสียหายที่ระบุ: 100.0 บาท'),
        findsOneWidget);
  });

  testWidgets('ปฏิเสธค่าปรับที่ไม่ใช่ตัวเลขหรือค่าติดลบ',
      (tester) async {
    await openDetail(tester);

    await tester.enterText(find.byType(TextField).first, '-5');
    final submitButton = find.text('ยืนยันรับคืนและคำนวณเงินมัดจำ');
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(
      find.text('กรุณากรอกค่าปรับเป็นตัวเลขตั้งแต่ 0 ขึ้นไป'),
      findsOneWidget,
    );
    expect(
      requests.any((r) =>
          r.method == 'PUT' && r.url.path == '/api/borrows/43/return'),
      isFalse,
    );
  });

  testWidgets('ส่งข้อมูลรับคืนและแสดงสรุปค่าปรับกับเงินมัดจำ',
      (tester) async {
    await openDetail(tester);

    await tester.enterText(find.byType(TextField).first, '100');
    final submitButton = find.text('ยืนยันรับคืนและคำนวณเงินมัดจำ');
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);

    // The page keeps its loading indicator active while the result dialog
    // is open, so pumpAndSettle would wait forever for the spinner to stop.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final returnRequest = requests.firstWhere(
      (r) => r.method == 'PUT' && r.url.path == '/api/borrows/43/return',
    );
    final body = jsonDecode(returnRequest.body) as Map<String, dynamic>;
    final items = body['items'] as List<dynamic>;

    expect(items, hasLength(2));
    expect(items.first, {
      'equipment_id': 31,
      'condition_after': 'good',
      'damage_fine': 100.0,
    });
    expect(find.text('บันทึกการรับคืนสำเร็จ'), findsOneWidget);
    expect(find.textContaining('ค่าปรับคืนล่าช้า: 30.0 บาท'), findsOneWidget);
    expect(find.textContaining('ค่าปรับความเสียหาย: 100.0 บาท'), findsOneWidget);
    expect(find.textContaining('ค่าปรับรวม: 130.0 บาท'), findsOneWidget);
    expect(find.textContaining('ยอดเงินมัดจำที่ต้องคืน: 370.0 บาท'), findsOneWidget);
    expect(find.textContaining('ค่าปรับส่วนเกินมัดจำ: 0.0 บาท'), findsOneWidget);

    await tester.tap(find.text('ตกลง'));
    await tester.pumpAndSettle();
  });

  testWidgets('แสดงข้อผิดพลาดเมื่อโหลดรายละเอียดไม่สำเร็จ',
      (tester) async {
    detailStatus = 500;

    await openDetail(tester);

    expect(find.textContaining('โหลดรายการอุปกรณ์ไม่สำเร็จ:'), findsOneWidget);
  });

  testWidgets('แสดงข้อความเมื่อคำขอไม่มีอุปกรณ์', (tester) async {
    ApiRepository.client = ApiClient(
      baseUrl: 'http://localhost:3000',
      client: MockClient((request) async => jsonResponse({
        'data': {'items': []}
      })),
    )..token = 'test-admin-token';

    await openDetail(tester);

    expect(find.text('ไม่พบอุปกรณ์ในคำขอนี้'), findsOneWidget);
  });

  testWidgets('แสดงข้อผิดพลาดเมื่อ API บันทึกการรับคืนไม่สำเร็จ',
      (tester) async {
    returnStatus = 500;

    await openDetail(tester);

    final submitButton = find.text('ยืนยันรับคืนและคำนวณเงินมัดจำ');
    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.textContaining('บันทึกการรับคืนไม่สำเร็จ'), findsOneWidget);
  });
}
