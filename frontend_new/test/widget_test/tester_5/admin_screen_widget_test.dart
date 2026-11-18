import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/admin/admin_home.dart';
import 'package:frontend/features/admin/data/api_repository.dart';
import 'package:frontend/features/admin/screens/admin_pending_borrow_screen.dart';
import 'package:frontend/features/admin/screens/admin_pending_slip_screen.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

class _FakeBaseRequest extends Fake implements http.BaseRequest {}

// Extra widget tests for the admin screens (approve requests, check slips,
// admin home). They cover what admin_approval_slip_test.dart does not:
// refresh / retry, busy state, item loading failures, slip image URL,
// slip dialog details, several cards, button order on the home screen.
//
// Approve screen: ApiRepository.client = ApiClient(client: MockHttpClient).
// Slip screen: repository uses top-level http.get / http.put -> http.runWithClient.
//
// Why _stubBackend: mocktail only matches a stub when the call has the SAME
// named arguments. ApiClient may call client.put(uri, headers:, body:) without
// `encoding:`, or use client.send(...). _stubBackend stubs every shape and
// routes all of them to one handler, so tests do not depend on that detail.

class _Call {
  _Call(this.method, this.url, this.body);
  final String method;
  final Uri url;
  final Object? body;
}

typedef _Handler = FutureOr<http.Response> Function(_Call call);

/// Stubs [mock] so every request goes to [handler]. Returns the recorded calls.
List<_Call> _stubBackend(MockHttpClient mock, _Handler handler) {
  final calls = <_Call>[];

  Future<http.Response> run(String method, Invocation inv) async {
    final call = _Call(
      method,
      inv.positionalArguments.first as Uri,
      inv.namedArguments[#body],
    );
    calls.add(call);
    return handler(call);
  }

  // GET: with / without headers.
  when(() => mock.get(any())).thenAnswer((i) => run('GET', i));
  when(() => mock.get(any(), headers: any(named: 'headers')))
      .thenAnswer((i) => run('GET', i));

  // PUT: every combination of headers / body / encoding that callers use.
  when(() => mock.put(any())).thenAnswer((i) => run('PUT', i));
  when(() => mock.put(any(), headers: any(named: 'headers')))
      .thenAnswer((i) => run('PUT', i));
  when(() => mock.put(any(), body: any(named: 'body')))
      .thenAnswer((i) => run('PUT', i));
  when(() => mock.put(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer((i) => run('PUT', i));
  when(() => mock.put(
        any(),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
        encoding: any(named: 'encoding'),
      )).thenAnswer((i) => run('PUT', i));

  // send(): used when ApiClient builds http.Request itself.
  when(() => mock.send(any())).thenAnswer((i) async {
    final req = i.positionalArguments.first as http.BaseRequest;
    final call = _Call(
      req.method,
      req.url,
      req is http.Request ? req.body : null,
    );
    calls.add(call);
    final r = await handler(call);
    return http.StreamedResponse(
      Stream.value(r.bodyBytes),
      r.statusCode,
      headers: r.headers,
      request: req,
    );
  });

  when(() => mock.close()).thenReturn(null);
  return calls;
}

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> _row(
  int id, {
  String status = 'approved',
  String payment = 'pending',
  String? slip,
  String userName = 'Test Renter',
  String purpose = 'Class project',
}) =>
    {
      'id': id,
      'user_id': 7,
      'user_name': userName,
      'item_count': 2,
      'purpose': purpose,
      'start_date': '2026-11-20',
      'end_date': '2026-11-22',
      'status': status,
      'total_price': '150.00',
      'total_deposit': '400.00',
      'payment_status': payment,
      'slip_url': slip,
      'fine_amount': '0.00',
      'fine_paid': 0,
      'items': [
        {'equipment_id': 31, 'equipment_name': 'Camera', 'asset_code': 'CAM-31'},
        {'equipment_id': 32, 'equipment_name': 'Tripod', 'asset_code': 'TRI-32'},
      ],
    };

ApiClient _apiClient(http.Client mockHttp) =>
    ApiClient(baseUrl: 'http://test', client: mockHttp)..token = 'admin-token';

void _bigScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _pumpApprove(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: AdminPendingBorrowScreen()));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://test'));
    registerFallbackValue(_FakeBaseRequest());
  });

  tearDown(() {
    ApiRepository.client = null;
  });

  // ------------------------------------------------------ approve screen

  // ============================================================
  // AdminPendingBorrowScreen (widget test เสริม)
  // path: lib/features/admin/screens/admin_pending_borrow_screen.dart
  // ============================================================
  group('AdminPendingBorrowScreen (extra)', () {
    // ทดสอบ: หน้าอนุมัติคำขอเช่า: ปุ่มรีเฟรชมุมขวาบนโหลดรายการใหม่
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState._reload
    testWidgets('refresh button loads the list again', (tester) async {
      _bigScreen(tester);
      final mockHttp = MockHttpClient();
      var rows = [_row(42, status: 'pending')];

      final calls = _stubBackend(mockHttp, (_) => _json(rows));
      ApiRepository.client = _apiClient(mockHttp);

      await _pumpApprove(tester);
      expect(calls.where((c) => c.method == 'GET'), hasLength(1));
      expect(find.text('คำขอ #43'), findsNothing);

      rows = [_row(42, status: 'pending'), _row(43, status: 'pending')];
      await tester.tap(find.byTooltip('โหลดรายการใหม่'));
      await tester.pumpAndSettle();

      expect(calls.where((c) => c.method == 'GET'), hasLength(2));
      expect(find.text('คำขอ #43'), findsOneWidget);
    });

    // ทดสอบ: หน้าอนุมัติคำขอเช่า: ปุ่ม "ลองอีกครั้ง" หลังโหลดพลาด
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState._reload
    testWidgets('retry button reloads after a load error', (tester) async {
      _bigScreen(tester);
      final mockHttp = MockHttpClient();
      var fail = true;

      _stubBackend(mockHttp, (_) {
        if (fail) return _json({'message': 'Server error'}, 500);
        return _json([_row(42, status: 'pending')]);
      });
      ApiRepository.client = _apiClient(mockHttp);

      await _pumpApprove(tester);
      expect(find.textContaining('โหลดคำขอไม่สำเร็จ'), findsOneWidget);
      expect(find.textContaining('เซิร์ฟเวอร์ขัดข้อง'), findsOneWidget);

      fail = false;
      await tester.tap(find.widgetWithText(OutlinedButton, 'ลองอีกครั้ง'));
      await tester.pumpAndSettle();

      expect(find.text('คำขอ #42'), findsOneWidget);
      expect(find.textContaining('โหลดคำขอไม่สำเร็จ'), findsNothing);
    });

    // ทดสอบ: หน้าอนุมัติคำขอเช่า: ระหว่างรอ backend ปุ่มถูกปิดและมีวงกลมหมุน
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState._busyRequestId
    testWidgets('while waiting for the server buttons are disabled + spinner',
        (tester) async {
      _bigScreen(tester);
      final mockHttp = MockHttpClient();
      final gate = Completer<http.Response>();

      _stubBackend(mockHttp, (c) {
        if (c.method == 'PUT') return gate.future;
        return _json([_row(42, status: 'pending')]);
      });
      ApiRepository.client = _apiClient(mockHttp);

      await _pumpApprove(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'อนุมัติ'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'อนุมัติ'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Spinner replaces the label on both buttons of the busy card.
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      for (final b in tester.widgetList<FilledButton>(find.byType(FilledButton))) {
        expect(b.onPressed, isNull);
      }
      for (final b
          in tester.widgetList<OutlinedButton>(find.byType(OutlinedButton))) {
        expect(b.onPressed, isNull);
      }
      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNull);

      gate.complete(_json({'message': 'ok'}));
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.widget<IconButton>(find.byType(IconButton)).onPressed, isNotNull);
    });

    // ทดสอบ: หน้าอนุมัติคำขอเช่า: วงกลมหมุนเฉพาะคำขอที่กำลังทำ
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState._busyRequestId
    testWidgets('only the card being processed is busy', (tester) async {
      _bigScreen(tester);
      final mockHttp = MockHttpClient();
      final gate = Completer<http.Response>();

      _stubBackend(mockHttp, (c) {
        if (c.method == 'PUT') return gate.future;
        return _json([_row(42, status: 'pending'), _row(43, status: 'pending')]);
      });
      ApiRepository.client = _apiClient(mockHttp);

      await _pumpApprove(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'อนุมัติ').first);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'อนุมัติ'),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 2 spinners = both buttons of card #42 only. Card #43 keeps its labels
      // but its buttons are disabled too (one request at a time).
      expect(find.byType(CircularProgressIndicator), findsNWidgets(2));
      expect(find.text('อนุมัติ'), findsOneWidget);

      gate.complete(_json({'message': 'ok'}));
      await tester.pumpAndSettle();
    });

    // ทดสอบ: หน้าอนุมัติคำขอเช่า: โหลดรายการอุปกรณ์ในการ์ดพลาด แสดงข้อความในการ์ด
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState._itemsFor
    testWidgets('item list load failure is shown inside the card', (tester) async {
      _bigScreen(tester);
      final mockHttp = MockHttpClient();
      final row = _row(42, status: 'pending')..remove('items');

      _stubBackend(mockHttp, (c) {
        if (c.url.path == '/api/borrows/42') {
          return _json({'message': 'Server error'}, 500);
        }
        return _json([row]);
      });
      ApiRepository.client = _apiClient(mockHttp);

      await _pumpApprove(tester);

      expect(find.text('คำขอ #42'), findsOneWidget);
      expect(find.textContaining('โหลดรายการอุปกรณ์ไม่สำเร็จ'), findsOneWidget);
    });

    // ทดสอบ: หน้าอนุมัติคำขอเช่า: คำขอไม่มีอุปกรณ์ แสดง "ไม่พบรายการอุปกรณ์ในคำขอนี้"
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState._itemsFor
    testWidgets('request with no items shows the empty-items text', (tester) async {
      _bigScreen(tester);
      final mockHttp = MockHttpClient();
      final row = _row(42, status: 'pending')..remove('items');

      _stubBackend(mockHttp, (c) {
        if (c.url.path == '/api/borrows/42') {
          return _json({
            'success': true,
            'data': {'items': []},
          });
        }
        return _json([row]);
      });
      ApiRepository.client = _apiClient(mockHttp);

      await _pumpApprove(tester);

      expect(find.text('ไม่พบรายการอุปกรณ์ในคำขอนี้'), findsOneWidget);
    });

    // ทดสอบ: หน้าอนุมัติคำขอเช่า: ไม่มีชื่อผู้ขอแสดง ID แทน, ไม่มีวัตถุประสงค์ซ่อนบรรทัด
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState.build
    testWidgets('empty user name falls back to ID, empty purpose is hidden',
        (tester) async {
      _bigScreen(tester);
      final mockHttp = MockHttpClient();
      _stubBackend(
        mockHttp,
        (_) => _json([_row(42, status: 'pending', userName: '', purpose: '')]),
      );
      ApiRepository.client = _apiClient(mockHttp);

      await _pumpApprove(tester);

      expect(find.text('ผู้ขอ: ID 7'), findsOneWidget);
      expect(find.textContaining('วัตถุประสงค์'), findsNothing);
    });

    // ทดสอบ: หน้าอนุมัติคำขอเช่า: แสดงจำนวนอุปกรณ์ ค่าเช่า มัดจำ และวัตถุประสงค์
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState.build
    testWidgets('shows price, deposit and item count', (tester) async {
      _bigScreen(tester);
      final mockHttp = MockHttpClient();
      _stubBackend(mockHttp, (_) => _json([_row(42, status: 'pending')]));
      ApiRepository.client = _apiClient(mockHttp);

      await _pumpApprove(tester);

      expect(find.text('จำนวนอุปกรณ์: 2 ชิ้น'), findsOneWidget);
      expect(find.text('ค่าเช่า 150.0 บาท · มัดจำ 400.0 บาท'), findsOneWidget);
      expect(find.text('วัตถุประสงค์: Class project'), findsOneWidget);
    });
  });

  // -------------------------------------------------------- slip screen

  // ============================================================
  // AdminPendingSlipScreen (widget test เสริม)
  // path: lib/features/admin/screens/admin_pending_slip_screen.dart
  // ============================================================
  group('AdminPendingSlipScreen (extra)', () {
    Future<void> withBackend(
      MockHttpClient mockHttp,
      Future<void> Function() body,
    ) {
      ApiRepository.client = _apiClient(mockHttp);
      return http.runWithClient(body, () => mockHttp);
    }

    Future<void> pumpSlip(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AdminPendingSlipScreen()));
      await tester.pumpAndSettle();
    }

    // ทดสอบ: หน้าตรวจสลิป: การ์ดแสดงเลขคำขอ User ID ยอดชำระ และวันที่
    // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState.build
    testWidgets('card shows request id, user id, total and dates', (tester) async {
      _bigScreen(tester);
      final mockHttp = MockHttpClient();
      _stubBackend(mockHttp, (_) => _json([_row(50, slip: '/uploads/slip-50.jpg')]));

      await withBackend(mockHttp, () async {
        await pumpSlip(tester);

        expect(find.text('คำขอรหัส: #50 (User ID: 7)'), findsOneWidget);
        expect(find.textContaining('ยอดชำระ: 550.0 บาท'), findsOneWidget);
        expect(find.textContaining('2026-11-20 ถึง 2026-11-22'), findsOneWidget);
      });
    });

    // ทดสอบ: หน้าตรวจสลิป: dialog แสดง User ID วัตถุประสงค์ ยอดรวม และมัดจำ
    // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState._showSlipDetailModal
    testWidgets('dialog shows user, purpose, price and deposit', (tester) async {
      _bigScreen(tester);
      final mockHttp = MockHttpClient();
      _stubBackend(mockHttp, (_) => _json([_row(50, slip: '/uploads/slip-50.jpg')]));

      await withBackend(mockHttp, () async {
        await pumpSlip(tester);
        await tester.tap(find.widgetWithText(ElevatedButton, 'ตรวจสลิป'));
        await tester.pumpAndSettle();

        expect(find.text('ผู้ใช้ ID: 7'), findsOneWidget);
        expect(find.text('วัตถุประสงค์: Class project'), findsOneWidget);
        expect(find.text('ยอดรวม: 150.0 บาท | มัดจำ: 400.0 บาท'), findsOneWidget);
        expect(find.text('รูปภาพสลิปโอนเงิน:'), findsOneWidget);
      });
    });

    // Image URL = server URL + path, unless slip_url is already a full URL.
    final urlCases = <String, String>{
      '/uploads/slip-50.jpg': '${ApiRepository.serverUrl}/uploads/slip-50.jpg',
      'uploads/slip-50.jpg': '${ApiRepository.serverUrl}/uploads/slip-50.jpg',
      'http://cdn.test/slip-50.jpg': 'http://cdn.test/slip-50.jpg',
    };
    for (final entry in urlCases.entries) {
      // ทดสอบ: หน้าตรวจสลิป: รูปสลิปใน dialog โหลดจาก URL (path ต่อกับ server หรือ URL เต็ม)
      // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState._showSlipDetailModal (Image.network)
      testWidgets('slip image url for "${entry.key}"', (tester) async {
        _bigScreen(tester);
        final mockHttp = MockHttpClient();
        _stubBackend(mockHttp, (_) => _json([_row(50, slip: entry.key)]));

        await withBackend(mockHttp, () async {
          await pumpSlip(tester);
          await tester.tap(find.widgetWithText(ElevatedButton, 'ตรวจสลิป'));
          await tester.pumpAndSettle();

          final image = tester.widget<Image>(find.byType(Image));
          expect((image.image as NetworkImage).url, entry.value);
        });
      });
    }

    // ทดสอบ: หน้าตรวจสลิป: รูปโหลดไม่ได้ แสดงข้อความแทนรูป
    // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState._showSlipDetailModal (errorBuilder)
    testWidgets('failed image shows fallback text', (tester) async {
      _bigScreen(tester);
      final mockHttp = MockHttpClient();
      _stubBackend(mockHttp, (_) => _json([_row(50, slip: '/uploads/slip-50.jpg')]));

      await withBackend(mockHttp, () async {
        await pumpSlip(tester);
        await tester.tap(find.widgetWithText(ElevatedButton, 'ตรวจสลิป'));
        await tester.pumpAndSettle();

        // flutter_test answers every network image with HTTP 400.
        expect(find.text('ไม่สามารถโหลดรูปภาพสลิปได้'), findsOneWidget);
      });
    });

    // ทดสอบ: หน้าตรวจสลิป: มีหลายใบ กดใบที่ 2 แล้ว dialog และการบันทึกเป็นของใบที่ 2
    // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState._showSlipDetailModal, _processVerification
    testWidgets('several requests: second card opens its own dialog', (tester) async {
      _bigScreen(tester);
      final mockHttp = MockHttpClient();

      final calls = _stubBackend(mockHttp, (c) {
        if (c.method == 'PUT') return _json({'success': true});
        return _json([
          _row(50, slip: '/uploads/slip-50.jpg'),
          _row(51, slip: '/uploads/slip-51.jpg'),
        ]);
      });

      await withBackend(mockHttp, () async {
        await pumpSlip(tester);

        expect(find.widgetWithText(ElevatedButton, 'ตรวจสลิป'), findsNWidgets(2));
        expect(find.textContaining('#50'), findsOneWidget);
        expect(find.textContaining('#51'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'ตรวจสลิป').at(1));
        await tester.pumpAndSettle();
        expect(find.text('ตรวจสอบสลิป (คำขอ # 51)'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยันสลิป (อนุมัติ)'));
        await tester.pumpAndSettle();

        final puts = calls.where((c) => c.method == 'PUT').toList();
        expect(puts, hasLength(1));
        expect(puts.single.url.path, '/api/borrows/51/verify-payment');
      });
    });

    // ทดสอบ: หน้าตรวจสลิป: หมายเหตุที่ส่งไปตอนยืนยัน/ปฏิเสธสลิป
    // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState._processVerification
    testWidgets('verify note: approve = สลิปถูกต้อง, reject = สลิปไม่ถูกต้อง',
        (tester) async {
      _bigScreen(tester);
      final mockHttp = MockHttpClient();

      final calls = _stubBackend(mockHttp, (c) {
        if (c.method == 'PUT') return _json({'success': true});
        return _json([_row(50, slip: '/uploads/slip-50.jpg')]);
      });

      await withBackend(mockHttp, () async {
        await pumpSlip(tester);

        await tester.tap(find.widgetWithText(ElevatedButton, 'ตรวจสลิป'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'ปฏิเสธสลิป'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'ตรวจสลิป'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยันสลิป (อนุมัติ)'));
        await tester.pumpAndSettle();

        final bodies = calls
            .where((c) => c.method == 'PUT')
            .map((c) => jsonDecode(c.body as String) as Map<String, dynamic>)
            .toList();

        expect(bodies, [
          {'payment_status': 'rejected', 'admin_note': 'สลิปไม่ถูกต้อง'},
          {'payment_status': 'paid', 'admin_note': 'สลิปถูกต้อง'},
        ]);
      });
    });

    // ทดสอบ: หน้าตรวจสลิป: หัวข้อหน้า
    // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState.build
    testWidgets('screen has its title', (tester) async {
      final mockHttp = MockHttpClient();
      _stubBackend(mockHttp, (_) => _json([]));

      await withBackend(mockHttp, () async {
        await pumpSlip(tester);
        expect(find.text('แดชบอร์ดตรวจสอบสลิปโอนเงิน'), findsOneWidget);
      });
    });
  });

  // ---------------------------------------------------------- admin home

  // ============================================================
  // AdminHome (widget test เสริม)
  // path: lib/features/admin/admin_home.dart
  // ============================================================
  group('AdminHome (extra)', () {
    const admin = AppUser(
      id: 1,
      username: 'admin',
      fullName: 'สมชาย ใจดี',
      role: UserRole.admin,
    );

    // ทดสอบ: หน้าแรกแอดมิน: หัวข้อ "ผู้ดูแลระบบ" และไอคอนออกจากระบบ
    // path: lib/features/admin/admin_home.dart -> AdminHome.build
    testWidgets('app bar title and logout icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AdminHome(user: admin, onLogout: () {}),
      ));

      expect(find.text('ผู้ดูแลระบบ'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    });

    // ทดสอบ: หน้าแรกแอดมิน: ลำดับปุ่มเมนูจากบนลงล่าง
    // path: lib/features/admin/admin_home.dart -> AdminHome.build
    testWidgets('menu buttons are in the expected order top to bottom',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AdminHome(user: admin, onLogout: () {}),
      ));

      final labels = [
        'จัดการอุปกรณ์',
        'เพิ่มหมวดหมู่',
        'อนุมัติคำขอเช่า',
        'ตรวจสอบสลิปโอนเงิน',
        'ส่งมอบ/รับคืนอุปกรณ์',
      ];
      final tops = [
        for (final l in labels)
          tester.getTopLeft(find.widgetWithText(FilledButton, l)).dy,
      ];

      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: labels[i]);
      }
    });

    // ทดสอบ: หน้าแรกแอดมิน: ข้อความทักทายใช้ชื่อแอดมินที่ล็อกอิน
    // path: lib/features/admin/admin_home.dart -> AdminHome.build
    testWidgets('greeting uses the full name of the logged-in admin', (tester) async {
      const other = AppUser(
        id: 2,
        username: 'admin2',
        fullName: 'ผู้ดูแล สอง',
        role: UserRole.admin,
      );
      await tester.pumpWidget(MaterialApp(
        home: AdminHome(user: other, onLogout: () {}),
      ));

      expect(find.text('สวัสดี ผู้ดูแล สอง'), findsOneWidget);
    });

    // ทดสอบ: หน้าแรกแอดมิน: เปิดหน้าอนุมัติแล้วกดกลับ กลับมาหน้าเมนู
    // path: lib/features/admin/admin_home.dart -> AdminHome._open
    testWidgets('back from the approval screen returns to the menu', (tester) async {
      final mockHttp = MockHttpClient();
      _stubBackend(mockHttp, (_) => _json([]));
      ApiRepository.client = _apiClient(mockHttp);

      await tester.pumpWidget(MaterialApp(
        home: AdminHome(user: admin, onLogout: () {}),
      ));

      await tester.tap(find.widgetWithText(FilledButton, 'อนุมัติคำขอเช่า'));
      await tester.pumpAndSettle();
      expect(find.byType(AdminPendingBorrowScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(AdminPendingBorrowScreen), findsNothing);
      expect(find.byType(AdminHome), findsOneWidget);
    });
  });
}