import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:frontend/core/api_client.dart';
import 'package:frontend/features/admin/data/api_repository.dart';
import 'package:frontend/features/admin/screens/admin_delivery_return_screen.dart';

Map<String, dynamic> borrow({
  required int id,
  required String status,
  String paymentStatus = 'paid',
}) => {
  'id': id,
  'user_id': 7,
  'user_name': 'ผู้เช่าทดสอบ',
  'item_count': 1,
  'purpose': 'ใช้ในการเรียน',
  'start_date': '2026-11-20',
  'end_date': '2026-11-22',
  'status': status,
  'total_price': 200,
  'total_deposit': 500,
  'payment_status': paymentStatus,
  'fine_amount': 0,
  'fine_paid': 0,
};

http.Response jsonResponse(Object body, {int statusCode = 200}) =>
    http.Response(jsonEncode(body), statusCode,
        headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> requests;
  late List<Map<String, dynamic>> serverRequests;

  setUp(() {
    requests = [];
    serverRequests = [
      borrow(id: 42, status: 'approved'),
      borrow(id: 43, status: 'borrowed'),
    ];
    ApiRepository.client = ApiClient(
      baseUrl: 'http://localhost:3000',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/api/borrows') {
          return jsonResponse(serverRequests);
        }
        if (request.method == 'PUT' &&
            request.url.path == '/api/borrows/42/handover') {
          return jsonResponse({'success': true});
        }
        if (request.method == 'GET' && request.url.path == '/api/borrows/43') {
          return jsonResponse({
            'data': {
              'items': [
                {
                  'equipment_id': 31,
                  'equipment_name': 'กล้องถ่ายรูป',
                  'asset_code': 'CAM-001',
                }
              ]
            }
          });
        }
        if (request.method == 'PUT' &&
            request.url.path == '/api/borrows/43/return') {
          return jsonResponse({
            'data': {
              'late_fine': 0,
              'total_damage_fine': 0,
              'fine_amount': 0,
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

  Future<void> openList(WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: AdminDeliveryReturnScreen()),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('แสดงรายการที่รอส่งมอบและรายการที่กำลังเช่า',
      (tester) async {
    await openList(tester);

    expect(find.text('ส่งมอบและรับคืนอุปกรณ์'), findsOneWidget);
    expect(find.text('คำขอ #42 · รอส่งมอบ'), findsOneWidget);
    expect(find.text('คำขอ #43 · กำลังเช่า'), findsOneWidget);
    expect(find.text('ผู้เช่า: ผู้เช่าทดสอบ'), findsNWidgets(2));
    expect(find.text('บันทึกการส่งมอบ'), findsOneWidget);
    expect(find.text('บันทึกการรับคืน'), findsOneWidget);
  });

  testWidgets('แสดงข้อความเมื่อไม่มีรายการส่งมอบหรือรับคืน',
      (tester) async {
    serverRequests = [];

    await openList(tester);

    expect(find.text('ไม่มีรายการที่รอส่งมอบหรือรับคืน'), findsOneWidget);
  });

  testWidgets('ยืนยันการส่งมอบแล้วเรียก API และโหลดรายการใหม่',
      (tester) async {
    await openList(tester);

    await tester.tap(find.text('บันทึกการส่งมอบ'));
    await tester.pumpAndSettle();

    expect(find.text('ยืนยันส่งมอบอุปกรณ์?'), findsOneWidget);
    await tester.tap(find.text('ยืนยันส่งมอบ'));
    await tester.pumpAndSettle();

    expect(
      requests.any((r) =>
          r.method == 'PUT' && r.url.path == '/api/borrows/42/handover'),
      isTrue,
    );
    expect(find.text('บันทึกการส่งมอบคำขอ #42 แล้ว'), findsOneWidget);
    expect(
      requests.where((r) =>
          r.method == 'GET' && r.url.path == '/api/borrows').length,
      2,
    );
  });

  testWidgets('กดยกเลิกในกล่องยืนยันส่งมอบแล้วไม่เรียก API',
      (tester) async {
    await openList(tester);

    await tester.tap(find.text('บันทึกการส่งมอบ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    expect(
      requests.any((r) =>
          r.method == 'PUT' && r.url.path == '/api/borrows/42/handover'),
      isFalse,
    );
  });

  testWidgets('กดบันทึกการรับคืนแล้วเปิดหน้ารายละเอียด',
      (tester) async {
    await openList(tester);

    await tester.tap(find.text('บันทึกการรับคืน'));
    await tester.pumpAndSettle();

    expect(find.text('จัดการรับคืนอุปกรณ์'), findsOneWidget);
    expect(find.text('รหัสคำขอยืม: #43'), findsOneWidget);
    expect(find.text('กล้องถ่ายรูป · CAM-001'), findsOneWidget);
    expect(
      requests.any((r) =>
          r.method == 'GET' && r.url.path == '/api/borrows/43'),
      isTrue,
    );
  });
}
