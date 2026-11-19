import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/admin/admin_home.dart';
import 'package:frontend/features/admin/data/api_repository.dart';
import 'package:frontend/features/admin/screens/admin_pending_borrow_screen.dart';
import 'package:frontend/features/admin/screens/admin_pending_slip_screen.dart';

// Extra widget tests for the admin screens (approve requests, check slips,
// admin home). They cover what admin_approval_slip_test.dart does not:
// refresh / retry, busy state, item loading failures, slip image URL,
// slip dialog details, several cards, button order on the home screen.
//
// Mocking: mocktail mocks http.Client.send (the lowest HTTP layer), so the
// real ApiClient / ApiRepository code (error translation, headers, parsing)
// still runs.
// Approve screen: ApiRepository.client -> ApiClient -> mock http client.
// Slip screen: repository uses top-level http.get / http.put
//              -> http.runWithClient -> same mock http client.

class MockHttpClient extends Mock implements http.Client {}

class FakeBaseRequest extends Fake implements http.BaseRequest {}

/// Real BaseClient that hands every request to the mocktail mock. get/put/post
/// all end up in send(), so one stubbed method covers whatever ApiClient calls.
class _ForwardingClient extends http.BaseClient {
  _ForwardingClient(this._mock);

  final http.Client _mock;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _mock.send(request);
}

late MockHttpClient mockHttp;

http.Response _json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

http.StreamedResponse _streamed(http.Response r) => http.StreamedResponse(
      Stream.value(r.bodyBytes),
      r.statusCode,
      headers: r.headers,
    );

/// Matches a request by HTTP method + URL path (query string ignored).
Matcher _request(String method, String path) => isA<http.BaseRequest>()
    .having((r) => r.method, 'method', method)
    .having((r) => r.url.path, 'path', path);

/// Stubs mockHttp.send for requests matching [matcher]. [answer] runs on every
/// call, so it can read variables that the test changes later.
void _whenSend(Matcher matcher, Future<http.Response> Function() answer) {
  when(() => mockHttp.send(any(that: matcher))).thenAnswer(
    (_) async => _streamed(await answer()),
  );
}

/// Counts requests that matched [matcher] so far.
VerificationResult _verifySent(Matcher matcher) =>
    verify(() => mockHttp.send(any(that: matcher)));

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

ApiClient _apiClient() =>
    ApiClient(baseUrl: 'http://test', client: _ForwardingClient(mockHttp))
      ..token = 'admin-token';

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
    registerFallbackValue(FakeBaseRequest());
  });

  setUp(() {
    mockHttp = MockHttpClient();
    // Default: any request nobody stubbed gets a 404 (later stubs win).
    when(() => mockHttp.send(any())).thenAnswer(
      (_) async => _streamed(_json({'message': 'Unexpected request'}, 404)),
    );
    ApiRepository.client = _apiClient();
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
    // ผลที่คาดหวัง: เปิดหน้ามา 1 คำขอ (#42) ยังไม่เห็น #43 -> backend เพิ่ม #43 -> กดปุ่มรีเฟรช
    //   จะเห็นคำขอ #43 โผล่ขึ้นมา และแอปยิง GET /api/borrows รวม 2 ครั้ง
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState._reload
    testWidgets('refresh button loads the list again', (tester) async {
      _bigScreen(tester);
      var rows = [_row(42, status: 'pending')];
      _whenSend(_request('GET', '/api/borrows'), () async => _json(rows));

      await _pumpApprove(tester);
      expect(find.text('คำขอ #43'), findsNothing);

      rows = [_row(42, status: 'pending'), _row(43, status: 'pending')];
      await tester.tap(find.byTooltip('โหลดรายการใหม่'));
      await tester.pumpAndSettle();

      expect(find.text('คำขอ #43'), findsOneWidget);
      // verify once only: mocktail does not count already-verified calls again.
      _verifySent(_request('GET', '/api/borrows')).called(2);
    });

    // ทดสอบ: หน้าอนุมัติคำขอเช่า: ปุ่ม "ลองอีกครั้ง" หลังโหลดพลาด
    // ผลที่คาดหวัง: backend ตอบ 500 -> เห็นข้อความ "โหลดคำขอไม่สำเร็จ" และ "เซิร์ฟเวอร์ขัดข้อง"
    //   พอ backend กลับมาปกติแล้วกด "ลองอีกครั้ง" -> เห็นคำขอ #42 และข้อความ error หายไป
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState._reload
    testWidgets('retry button reloads after a load error', (tester) async {
      _bigScreen(tester);
      var fail = true;
      _whenSend(_request('GET', '/api/borrows'), () async {
        if (fail) return _json({'message': 'Server error'}, 500);
        return _json([_row(42, status: 'pending')]);
      });

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
    // ผลที่คาดหวัง: กดอนุมัติแล้ว backend ยังไม่ตอบ -> ทั้งสองปุ่มของการ์ดมีวงกลมหมุน (2 อัน)
    //   ปุ่ม FilledButton / OutlinedButton / ปุ่มรีเฟรชกดไม่ได้ (onPressed เป็น null)
    //   พอ backend ตอบแล้ว -> วงกลมหายไป ปุ่มรีเฟรชกลับมากดได้
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState._busyRequestId
    testWidgets('while waiting for the server buttons are disabled + spinner',
        (tester) async {
      _bigScreen(tester);
      final gate = Completer<http.Response>();
      _whenSend(_request('PUT', '/api/borrows/42/approve'), () => gate.future);
      _whenSend(_request('GET', '/api/borrows'),
          () async => _json([_row(42, status: 'pending')]));

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
    // ผลที่คาดหวัง: มี 2 คำขอ กดอนุมัติ #42 ค้างไว้ -> วงกลมหมุนเฉพาะการ์ด #42 (2 อัน)
    //   การ์ด #43 ยังเห็นข้อความ "อนุมัติ" (1 ข้อความ) แต่ปุ่มถูกปิดเพราะทำได้ทีละคำขอ
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState._busyRequestId
    testWidgets('only the card being processed is busy', (tester) async {
      _bigScreen(tester);
      final gate = Completer<http.Response>();
      _whenSend(_request('PUT', '/api/borrows/42/approve'), () => gate.future);
      _whenSend(
        _request('GET', '/api/borrows'),
        () async => _json([_row(42, status: 'pending'), _row(43, status: 'pending')]),
      );

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
    // ผลที่คาดหวัง: ดึงรายการอุปกรณ์ของ #42 ไม่ได้ (500) -> การ์ด #42 ยังแสดงอยู่
    //   และมีข้อความ "โหลดรายการอุปกรณ์ไม่สำเร็จ" ในการ์ด ไม่ล้มทั้งหน้า
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState._itemsFor
    testWidgets('item list load failure is shown inside the card', (tester) async {
      _bigScreen(tester);
      final row = _row(42, status: 'pending')..remove('items');
      _whenSend(_request('GET', '/api/borrows/42'),
          () async => _json({'message': 'Server error'}, 500));
      _whenSend(_request('GET', '/api/borrows'), () async => _json([row]));

      await _pumpApprove(tester);

      expect(find.text('คำขอ #42'), findsOneWidget);
      expect(find.textContaining('โหลดรายการอุปกรณ์ไม่สำเร็จ'), findsOneWidget);
    });

    // ทดสอบ: หน้าอนุมัติคำขอเช่า: คำขอไม่มีอุปกรณ์ แสดง "ไม่พบรายการอุปกรณ์ในคำขอนี้"
    // ผลที่คาดหวัง: backend ตอบรายการอุปกรณ์ว่าง -> การ์ดแสดง "ไม่พบรายการอุปกรณ์ในคำขอนี้"
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState._itemsFor
    testWidgets('request with no items shows the empty-items text', (tester) async {
      _bigScreen(tester);
      final row = _row(42, status: 'pending')..remove('items');
      _whenSend(
        _request('GET', '/api/borrows/42'),
        () async => _json({
          'success': true,
          'data': {'items': []},
        }),
      );
      _whenSend(_request('GET', '/api/borrows'), () async => _json([row]));

      await _pumpApprove(tester);

      expect(find.text('ไม่พบรายการอุปกรณ์ในคำขอนี้'), findsOneWidget);
    });

    // ทดสอบ: หน้าอนุมัติคำขอเช่า: ไม่มีชื่อผู้ขอแสดง ID แทน, ไม่มีวัตถุประสงค์ซ่อนบรรทัด
    // ผลที่คาดหวัง: user_name ว่าง -> แสดง "ผู้ขอ: ID 7"
    //   purpose ว่าง -> ไม่มีบรรทัด "วัตถุประสงค์" เลย
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState.build
    testWidgets('empty user name falls back to ID, empty purpose is hidden',
        (tester) async {
      _bigScreen(tester);
      _whenSend(
        _request('GET', '/api/borrows'),
        () async => _json([_row(42, status: 'pending', userName: '', purpose: '')]),
      );

      await _pumpApprove(tester);

      expect(find.text('ผู้ขอ: ID 7'), findsOneWidget);
      expect(find.textContaining('วัตถุประสงค์'), findsNothing);
    });

    // ทดสอบ: หน้าอนุมัติคำขอเช่า: แสดงจำนวนอุปกรณ์ ค่าเช่า มัดจำ และวัตถุประสงค์
    // ผลที่คาดหวัง: การ์ดแสดง "จำนวนอุปกรณ์: 2 ชิ้น", "ค่าเช่า 150.0 บาท · มัดจำ 400.0 บาท"
    //   และ "วัตถุประสงค์: Class project" (ค่าเงินจาก backend เป็นสตริง แปลงเป็นเลขได้ถูก)
    // path: lib/features/admin/screens/admin_pending_borrow_screen.dart -> _AdminPendingBorrowScreenState.build
    testWidgets('shows price, deposit and item count', (tester) async {
      _bigScreen(tester);
      _whenSend(_request('GET', '/api/borrows'),
          () async => _json([_row(42, status: 'pending')]));

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
    // The slip repository calls top-level http.get / http.put, so the body runs
    // inside http.runWithClient with the same mocktail-backed client.
    Future<void> withBackend(Future<void> Function() body) =>
        http.runWithClient(body, () => _ForwardingClient(mockHttp));

    Future<void> pumpSlip(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: AdminPendingSlipScreen()));
      await tester.pumpAndSettle();
    }

    // ทดสอบ: หน้าตรวจสลิป: การ์ดแสดงเลขคำขอ User ID ยอดชำระ และวันที่
    // ผลที่คาดหวัง: การ์ดแสดง "คำขอรหัส: #50 (User ID: 7)", ยอดชำระ 550.0 บาท (ค่าเช่า 150 + มัดจำ 400)
    //   และช่วงวันที่ "2026-11-20 ถึง 2026-11-22"
    // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState.build
    testWidgets('card shows request id, user id, total and dates', (tester) async {
      _bigScreen(tester);
      _whenSend(_request('GET', '/api/borrows'),
          () async => _json([_row(50, slip: '/uploads/slip-50.jpg')]));

      await withBackend(() async {
        await pumpSlip(tester);

        expect(find.text('คำขอรหัส: #50 (User ID: 7)'), findsOneWidget);
        expect(find.textContaining('ยอดชำระ: 550.0 บาท'), findsOneWidget);
        expect(find.textContaining('2026-11-20 ถึง 2026-11-22'), findsOneWidget);
      });
    });

    // ทดสอบ: หน้าตรวจสลิป: dialog แสดง User ID วัตถุประสงค์ ยอดรวม และมัดจำ
    // ผลที่คาดหวัง: กด "ตรวจสลิป" -> dialog แสดง "ผู้ใช้ ID: 7", "วัตถุประสงค์: Class project",
    //   "ยอดรวม: 150.0 บาท | มัดจำ: 400.0 บาท" และหัวข้อ "รูปภาพสลิปโอนเงิน:"
    // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState._showSlipDetailModal
    testWidgets('dialog shows user, purpose, price and deposit', (tester) async {
      _bigScreen(tester);
      _whenSend(_request('GET', '/api/borrows'),
          () async => _json([_row(50, slip: '/uploads/slip-50.jpg')]));

      await withBackend(() async {
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
      // ผลที่คาดหวัง (ทดสอบ 3 กรณี): "/uploads/slip-50.jpg" และ "uploads/slip-50.jpg" (ไม่มี /) ต้องต่อกับ server URL เป็น
      //   <serverUrl>/uploads/slip-50.jpg เหมือนกัน ส่วน URL เต็ม "http://cdn.test/..." ต้องใช้ตามนั้นไม่ต่อซ้ำ
      // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState._showSlipDetailModal (Image.network)
      testWidgets('slip image url for "${entry.key}"', (tester) async {
        _bigScreen(tester);
        _whenSend(_request('GET', '/api/borrows'),
            () async => _json([_row(50, slip: entry.key)]));

        await withBackend(() async {
          await pumpSlip(tester);
          await tester.tap(find.widgetWithText(ElevatedButton, 'ตรวจสลิป'));
          await tester.pumpAndSettle();

          final image = tester.widget<Image>(find.byType(Image));
          expect((image.image as NetworkImage).url, entry.value);
        });
      });
    }

    // ทดสอบ: หน้าตรวจสลิป: รูปโหลดไม่ได้ แสดงข้อความแทนรูป
    // ผลที่คาดหวัง: รูปสลิปโหลดไม่สำเร็จ (flutter_test ตอบรูปเครือข่ายด้วย HTTP 400 เสมอ)
    //   -> dialog แสดง "ไม่สามารถโหลดรูปภาพสลิปได้" แทนรูป
    // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState._showSlipDetailModal (errorBuilder)
    testWidgets('failed image shows fallback text', (tester) async {
      _bigScreen(tester);
      _whenSend(_request('GET', '/api/borrows'),
          () async => _json([_row(50, slip: '/uploads/slip-50.jpg')]));

      await withBackend(() async {
        await pumpSlip(tester);
        await tester.tap(find.widgetWithText(ElevatedButton, 'ตรวจสลิป'));
        await tester.pumpAndSettle();

        // flutter_test answers every network image with HTTP 400.
        expect(find.text('ไม่สามารถโหลดรูปภาพสลิปได้'), findsOneWidget);
      });
    });

    // ทดสอบ: หน้าตรวจสลิป: มีหลายใบ กดใบที่ 2 แล้ว dialog และการบันทึกเป็นของใบที่ 2
    // ผลที่คาดหวัง: มี 2 การ์ด (#50, #51) กดใบที่ 2 -> dialog ชื่อ "ตรวจสอบสลิป (คำขอ # 51)"
    //   กดยืนยัน -> ยิง PUT /api/borrows/51/verify-payment 1 ครั้ง และไม่ยิงของ #50 เลย
    // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState._showSlipDetailModal, _processVerification
    testWidgets('several requests: second card opens its own dialog', (tester) async {
      _bigScreen(tester);
      _whenSend(
        _request('GET', '/api/borrows'),
        () async => _json([
          _row(50, slip: '/uploads/slip-50.jpg'),
          _row(51, slip: '/uploads/slip-51.jpg'),
        ]),
      );
      _whenSend(_request('PUT', '/api/borrows/51/verify-payment'),
          () async => _json({'success': true}));

      await withBackend(() async {
        await pumpSlip(tester);

        expect(find.widgetWithText(ElevatedButton, 'ตรวจสลิป'), findsNWidgets(2));
        expect(find.textContaining('#50'), findsOneWidget);
        expect(find.textContaining('#51'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'ตรวจสลิป').at(1));
        await tester.pumpAndSettle();
        expect(find.text('ตรวจสอบสลิป (คำขอ # 51)'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยันสลิป (อนุมัติ)'));
        await tester.pumpAndSettle();

        _verifySent(_request('PUT', '/api/borrows/51/verify-payment')).called(1);
        verifyNever(() => mockHttp.send(
            any(that: _request('PUT', '/api/borrows/50/verify-payment'))));
      });
    });

    // ทดสอบ: หน้าตรวจสลิป: หมายเหตุที่ส่งไปตอนยืนยัน/ปฏิเสธสลิป
    // ผลที่คาดหวัง: กดปฏิเสธ -> body = {payment_status: rejected, admin_note: สลิปไม่ถูกต้อง}
    //   กดยืนยัน -> body = {payment_status: paid, admin_note: สลิปถูกต้อง} เรียงตามลำดับที่กด
    // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState._processVerification
    testWidgets('verify note: approve = สลิปถูกต้อง, reject = สลิปไม่ถูกต้อง',
        (tester) async {
      _bigScreen(tester);
      _whenSend(_request('GET', '/api/borrows'),
          () async => _json([_row(50, slip: '/uploads/slip-50.jpg')]));
      _whenSend(_request('PUT', '/api/borrows/50/verify-payment'),
          () async => _json({'success': true}));

      await withBackend(() async {
        await pumpSlip(tester);

        await tester.tap(find.widgetWithText(ElevatedButton, 'ตรวจสลิป'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'ปฏิเสธสลิป'));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(ElevatedButton, 'ตรวจสลิป'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'ยืนยันสลิป (อนุมัติ)'));
        await tester.pumpAndSettle();

        final sent = verify(() => mockHttp.send(captureAny(
              that: _request('PUT', '/api/borrows/50/verify-payment'),
            ))).captured;
        final bodies = [
          for (final r in sent)
            jsonDecode((r as http.Request).body) as Map<String, dynamic>,
        ];

        expect(bodies, [
          {'payment_status': 'rejected', 'admin_note': 'สลิปไม่ถูกต้อง'},
          {'payment_status': 'paid', 'admin_note': 'สลิปถูกต้อง'},
        ]);
      });
    });

    // ทดสอบ: หน้าตรวจสลิป: หัวข้อหน้า
    // ผลที่คาดหวัง: แม้ไม่มีรายการ หัวข้อ AppBar แสดง "แดชบอร์ดตรวจสอบสลิปโอนเงิน"
    // path: lib/features/admin/screens/admin_pending_slip_screen.dart -> _AdminPendingSlipScreenState.build
    testWidgets('screen has its title', (tester) async {
      _whenSend(_request('GET', '/api/borrows'), () async => _json([]));

      await withBackend(() async {
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
    // ผลที่คาดหวัง: AppBar แสดง "ผู้ดูแลระบบ" และมีไอคอนออกจากระบบ 1 อัน
    // path: lib/features/admin/admin_home.dart -> AdminHome.build
    testWidgets('app bar title and logout icon', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: AdminHome(user: admin, onLogout: () {}),
      ));

      expect(find.text('ผู้ดูแลระบบ'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
    });

    // ทดสอบ: หน้าแรกแอดมิน: ลำดับปุ่มเมนูจากบนลงล่าง
    // ผลที่คาดหวัง: ปุ่มเมนู 5 ปุ่มเรียงจากบนลงล่างตามลำดับ: จัดการอุปกรณ์ -> เพิ่มหมวดหมู่ ->
    //   อนุมัติคำขอเช่า -> ตรวจสอบสลิปโอนเงิน -> ส่งมอบ/รับคืนอุปกรณ์ (ตำแหน่งแนวตั้งของแต่ละปุ่มต้องเพิ่มขึ้นเรื่อย ๆ)
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
    // ผลที่คาดหวัง: ล็อกอินเป็น "ผู้ดูแล สอง" -> แสดง "สวัสดี ผู้ดูแล สอง" (ใช้ชื่อเต็มของ user ที่ส่งเข้ามา)
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
    // ผลที่คาดหวัง: กด "อนุมัติคำขอเช่า" -> เปิดหน้า AdminPendingBorrowScreen
    //   กดย้อนกลับ -> หน้านั้นหายไป เหลือหน้า AdminHome
    // path: lib/features/admin/admin_home.dart -> AdminHome._open
    testWidgets('back from the approval screen returns to the menu', (tester) async {
      _whenSend(_request('GET', '/api/borrows'), () async => _json([]));
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