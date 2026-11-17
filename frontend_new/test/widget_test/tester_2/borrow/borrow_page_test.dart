import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/dates.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/borrow/borrow_models.dart';
import 'package:frontend/features/borrow/borrow_page.dart';
import 'package:frontend/features/borrow/borrow_repository.dart';

/// Widget test ของหน้า "ส่งคำขอเช่า" (หน้าจอง)
/// ใช้ repository ปลอม จึงไม่เรียก backend
/// ปฏิทินเปิดที่เดือนปัจจุบัน แต่ test กดไปเดือนหน้าก่อนเสมอ
/// เพราะวันในเดือนหน้าเป็นอนาคตทั้งหมด ผลจึงไม่ขึ้นกับวันที่รัน test

class _FakeBorrowRepo implements BorrowRepository {
  Map<int, List<DateRange>> booked = {};
  Object? fetchError;
  Object? createError;
  Completer<void>? createGate;
  Completer<void>? fetchGate;

  final fetchedIds = <int>[];
  final createCalls =
      <({List<int> ids, String purpose, DateTime start, DateTime end})>[];

  @override
  Future<List<DateRange>> fetchBookedRanges(int equipmentId) async {
    fetchedIds.add(equipmentId);
    await fetchGate?.future;
    if (fetchError != null) throw fetchError!;
    return booked[equipmentId] ?? [];
  }

  @override
  Future<List<BorrowRequest>> create({
    required List<int> equipmentIds,
    required String purpose,
    required DateTime start,
    required DateTime end,
  }) async {
    createCalls.add((ids: equipmentIds, purpose: purpose, start: start, end: end));
    await createGate?.future;
    if (createError != null) throw createError!;
    return [];
  }

  @override
  Future<List<BorrowRequest>> fetchMine({String tab = 'all'}) async => [];
  @override
  Future<BorrowRequest> fetchOne(int id) => throw UnimplementedError();
  @override
  Future<BorrowRequest> cancel(int id) => throw UnimplementedError();
  @override
  Future<void> uploadSlip({
    required int requestId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {}
}

const _camera = Equipment(
  id: 1,
  assetCode: 'CAM-001',
  name: 'กล้อง DSLR',
  categoryId: 1,
  categoryName: 'กล้อง',
  status: EquipmentStatus.available,
);
const _mic = Equipment(
  id: 2,
  assetCode: 'MIC-001',
  name: 'ไมโครโฟน',
  categoryId: 2,
  categoryName: 'เครื่องเสียง',
  status: EquipmentStatus.available,
);

/// เดือนหน้า: วันที่ในเดือนนี้ทุกวันอยู่ในอนาคตแน่นอน
final DateTime _nextMonth = () {
  final n = DateTime.now();
  return DateTime(n.year, n.month + 1);
}();

DateTime _day(int d) => DateTime(_nextMonth.year, _nextMonth.month, d);

Future<void> _show(
  WidgetTester tester,
  _FakeBorrowRepo repo, {
  List<Equipment> items = const [_camera],
}) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: BorrowRequestPage(items: items, borrowRepo: repo),
  ));
  await tester.pumpAndSettle();
}

/// กดลูกศรไปเดือนหน้า
Future<void> _goNextMonth(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.chevron_right_rounded));
  await tester.pumpAndSettle();
}

Future<void> _tapDay(WidgetTester tester, int d) async {
  await tester.tap(find.text('$d'));
  await tester.pumpAndSettle();
}

Finder _submitButton() => find.widgetWithText(FilledButton, 'ส่งคำขอเช่า');

Future<void> _fillPurpose(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextFormField), text);
  await tester.pump();
}

void main() {
  group('BorrowRequestPage แสดงผล', () {
    testWidgets('แสดงรายการอุปกรณ์ที่เลือก', (tester) async {
      await _show(tester, _FakeBorrowRepo(), items: [_camera, _mic]);

      expect(find.text('อุปกรณ์ 2 ชิ้น'), findsOneWidget);
      expect(find.text('กล้อง DSLR'), findsOneWidget);
      expect(find.text('CAM-001 · กล้อง'), findsOneWidget);
      expect(find.text('ไมโครโฟน'), findsOneWidget);
      expect(find.text('MIC-001 · เครื่องเสียง'), findsOneWidget);
    });

    testWidgets('โหลดวันที่ถูกจองของอุปกรณ์ทุกชิ้น', (tester) async {
      final repo = _FakeBorrowRepo();
      await _show(tester, repo, items: [_camera, _mic]);

      expect(repo.fetchedIds, unorderedEquals([1, 2]));
    });

    testWidgets('ระหว่างโหลดปฏิทินแสดงวงกลมหมุน แล้วแสดงปฏิทินเมื่อโหลดเสร็จ', (tester) async {
      final repo = _FakeBorrowRepo()..fetchGate = Completer<void>();
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: BorrowRequestPage(items: const [_camera], borrowRepo: repo),
      ));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('จ'), findsNothing); // ยังไม่มีหัวตารางปฏิทิน

      repo.fetchGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('จ'), findsOneWidget);
    });

    testWidgets('มีหมายเหตุวันที่ถูกจองก็ต่อเมื่อเลือกหลายชิ้น', (tester) async {
      const note = 'วันที่ถูกจองของอุปกรณ์ชิ้นใดชิ้นหนึ่ง จะเลือกไม่ได้สำหรับทั้งคำขอ';

      await _show(tester, _FakeBorrowRepo(), items: [_camera]);
      expect(find.text(note), findsNothing);

      await _show(tester, _FakeBorrowRepo(), items: [_camera, _mic]);
      expect(find.text(note), findsOneWidget);
    });

    testWidgets('ปุ่มกลับปิดหน้านี้', (tester) async {
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => BorrowRequestPage(
                  items: const [_camera],
                  borrowRepo: _FakeBorrowRepo(),
                ),
              )),
              child: const Text('เปิดหน้าเช่า'),
            ),
          ),
        ),
      ));

      await tester.tap(find.text('เปิดหน้าเช่า'));
      await tester.pumpAndSettle();
      expect(find.text('อุปกรณ์ 1 ชิ้น'), findsOneWidget);

      await tester.tap(find.byTooltip('กลับ'));
      await tester.pumpAndSettle();
      expect(find.text('อุปกรณ์ 1 ชิ้น'), findsNothing);
    });
  });

  group('BorrowRequestPage เลือกวันที่', () {
    testWidgets('เริ่มต้นแสดงคำแนะนำให้แตะเลือกวัน', (tester) async {
      await _show(tester, _FakeBorrowRepo());
      expect(find.text('แตะเลือกวันที่เช่า แล้วแตะวันที่คืน'), findsOneWidget);
    });

    testWidgets('แตะวันเริ่มแล้วแตะวันคืน แสดงช่วงที่เลือกและบอกว่าส่งได้', (tester) async {
      await _show(tester, _FakeBorrowRepo());
      await _goNextMonth(tester);

      await _tapDay(tester, 10);
      expect(find.textContaining('เช่าวันที่ ${thaiShortDate(_day(10))}'), findsOneWidget);

      await _tapDay(tester, 12);
      expect(
        find.text('เลือก ${thaiRangeLabel(_day(10), _day(12))} ว่าง ส่งคำขอได้'),
        findsOneWidget,
      );
    });

    testWidgets('แตะวันเดิมซ้ำ = เช่าและคืนวันเดียวกัน', (tester) async {
      await _show(tester, _FakeBorrowRepo());
      await _goNextMonth(tester);

      await _tapDay(tester, 15);
      await _tapDay(tester, 15);
      expect(
        find.text('เลือก ${thaiShortDate(_day(15))} ว่าง ส่งคำขอได้'),
        findsOneWidget,
      );
    });

    testWidgets('แตะวันก่อนวันเริ่ม จะย้ายวันเริ่มมาที่วันนั้น', (tester) async {
      await _show(tester, _FakeBorrowRepo());
      await _goNextMonth(tester);

      await _tapDay(tester, 20);
      await _tapDay(tester, 18);
      expect(find.textContaining('เช่าวันที่ ${thaiShortDate(_day(18))}'), findsOneWidget);
    });

    testWidgets('วันที่ถูกจองแล้วเลือกไม่ได้', (tester) async {
      final repo = _FakeBorrowRepo()
        ..booked = {
          1: [DateRange(_day(10), _day(11))],
        };
      await _show(tester, repo);
      await _goNextMonth(tester);

      await _tapDay(tester, 10); // วันที่ถูกจอง
      expect(find.text('แตะเลือกวันที่เช่า แล้วแตะวันที่คืน'), findsOneWidget);

      await _tapDay(tester, 12); // วันว่าง เลือกได้
      expect(find.textContaining('เช่าวันที่ ${thaiShortDate(_day(12))}'), findsOneWidget);
    });

    testWidgets('วันที่ถูกจองของชิ้นใดชิ้นหนึ่ง ใช้ไม่ได้ทั้งคำขอ', (tester) async {
      final repo = _FakeBorrowRepo()
        ..booked = {
          2: [DateRange(_day(10), _day(10))], // ไมค์ถูกจอง กล้องว่าง
        };
      await _show(tester, repo, items: [_camera, _mic]);
      await _goNextMonth(tester);

      await _tapDay(tester, 10);
      expect(find.text('แตะเลือกวันที่เช่า แล้วแตะวันที่คืน'), findsOneWidget);
    });

    testWidgets('ช่วงที่คร่อมวันที่ถูกจอง ขึ้นข้อความเตือนและเริ่มเลือกใหม่', (tester) async {
      final repo = _FakeBorrowRepo()
        ..booked = {
          1: [DateRange(_day(15), _day(15))],
        };
      await _show(tester, repo);
      await _goNextMonth(tester);

      await _tapDay(tester, 14);
      await _tapDay(tester, 16);
      expect(
        find.text('ช่วงที่เลือกมีวันที่ถูกจองแล้ว กรุณาเลือกช่วงอื่น'),
        findsOneWidget,
      );
      expect(find.textContaining('ว่าง ส่งคำขอได้'), findsNothing);
    });
  });

  group('BorrowRequestPage ตรวจข้อมูลก่อนส่ง', () {
    testWidgets('ไม่กรอกวัตถุประสงค์ แจ้งเตือนและไม่เรียก create', (tester) async {
      final repo = _FakeBorrowRepo();
      await _show(tester, repo);
      await _goNextMonth(tester);
      await _tapDay(tester, 10);
      await _tapDay(tester, 11);

      await tester.tap(_submitButton());
      await tester.pumpAndSettle();

      expect(find.text('กรุณากรอกวัตถุประสงค์'), findsOneWidget);
      expect(repo.createCalls, isEmpty);
    });

    testWidgets('วัตถุประสงค์ยาวเกิน 500 ตัวอักษร แจ้งเตือน', (tester) async {
      final repo = _FakeBorrowRepo();
      await _show(tester, repo);
      await _fillPurpose(tester, 'ก' * 501);

      await tester.tap(_submitButton());
      await tester.pumpAndSettle();

      expect(find.text('ยาวเกินไป (สูงสุด 500 ตัวอักษร)'), findsOneWidget);
      expect(repo.createCalls, isEmpty);
    });

    testWidgets('กรอกวัตถุประสงค์แต่ไม่เลือกวัน แจ้งให้เลือกวันในปฏิทิน', (tester) async {
      final repo = _FakeBorrowRepo();
      await _show(tester, repo);
      await _fillPurpose(tester, 'ถ่ายกิจกรรม');

      await tester.tap(_submitButton());
      await tester.pumpAndSettle();

      expect(find.text('กรุณาเลือกวันที่เช่าและวันที่คืนในปฏิทิน'), findsOneWidget);
      expect(repo.createCalls, isEmpty);
    });
  });

  group('BorrowRequestPage ส่งคำขอ', () {
    testWidgets('ส่งสำเร็จ: เรียก create ด้วยข้อมูลที่กรอก ปิดหน้าด้วย true และแสดง snackbar',
        (tester) async {
      final repo = _FakeBorrowRepo();
      tester.view.physicalSize = const Size(900, 3000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      bool? result;

      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(MaterialPageRoute(
                  builder: (_) => BorrowRequestPage(
                    items: const [_camera, _mic],
                    borrowRepo: repo,
                  ),
                ));
              },
              child: const Text('เปิดหน้าเช่า'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('เปิดหน้าเช่า'));
      await tester.pumpAndSettle();

      await _fillPurpose(tester, '  ถ่ายกิจกรรม  ');
      await _goNextMonth(tester);
      await _tapDay(tester, 10);
      await _tapDay(tester, 12);
      await tester.tap(_submitButton());
      await tester.pumpAndSettle();

      expect(repo.createCalls, hasLength(1));
      final call = repo.createCalls.single;
      expect(call.ids, [1, 2]);
      expect(call.purpose, 'ถ่ายกิจกรรม'); // ตัดช่องว่างหัวท้าย
      expect(dayKey(call.start), dayKey(_day(10)));
      expect(dayKey(call.end), dayKey(_day(12)));
      expect(result, isTrue);
      expect(find.text('อุปกรณ์ 2 ชิ้น'), findsNothing); // กลับหน้าเดิมแล้ว
      expect(find.text('ส่งคำขอเช่า 2 ชิ้นแล้ว รอผู้ดูแลอนุมัติ'), findsOneWidget);
    });

    testWidgets('ระหว่างส่ง: ปุ่มกดไม่ได้และแสดงวงกลมหมุน', (tester) async {
      final repo = _FakeBorrowRepo()..createGate = Completer<void>();
      await _show(tester, repo);
      await _fillPurpose(tester, 'ถ่ายกิจกรรม');
      await _goNextMonth(tester);
      await _tapDay(tester, 10);
      await _tapDay(tester, 11);

      await tester.tap(_submitButton());
      await tester.pump();

      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repo.createGate!.complete();
      await tester.pumpAndSettle();
    });

    testWidgets('อุปกรณ์ไม่ว่าง: แสดงเหตุผลรายชิ้นและโหลดปฏิทินใหม่', (tester) async {
      final repo = _FakeBorrowRepo()
        ..createError = const ApiException(
          'ส่งคำขอไม่ได้',
          code: 'EQUIPMENT_UNAVAILABLE',
          details: [
            {'equipment_id': 1, 'reason': 'DATE_BOOKED'},
            {'equipment_id': 2, 'reason': 'NOT_AVAILABLE'},
          ],
        );
      await _show(tester, repo, items: [_camera, _mic]);
      await _fillPurpose(tester, 'ถ่ายกิจกรรม');
      await _goNextMonth(tester);
      await _tapDay(tester, 10);
      await _tapDay(tester, 11);
      final fetchesBefore = repo.fetchedIds.length;

      await tester.tap(_submitButton());
      await tester.pumpAndSettle();

      expect(find.textContaining('ส่งคำขอไม่ได้'), findsOneWidget);
      expect(find.textContaining('• กล้อง DSLR: ช่วงวันที่นี้ถูกจองแล้ว'), findsOneWidget);
      expect(find.textContaining('• ไมโครโฟน: ไม่พร้อมให้เช่า'), findsOneWidget);
      expect(repo.fetchedIds.length, greaterThan(fetchesBefore)); // โหลดปฏิทินใหม่
      expect(tester.widget<FilledButton>(_submitButton()).onPressed, isNotNull);
    });

    testWidgets('error อื่นจาก backend แสดงข้อความของ backend', (tester) async {
      final repo = _FakeBorrowRepo()..createError = const ApiException('สิทธิ์ไม่เพียงพอ');
      await _show(tester, repo);
      await _fillPurpose(tester, 'ถ่ายกิจกรรม');
      await _goNextMonth(tester);
      await _tapDay(tester, 10);
      await _tapDay(tester, 11);

      await tester.tap(_submitButton());
      await tester.pumpAndSettle();

      expect(find.text('สิทธิ์ไม่เพียงพอ'), findsOneWidget);
    });

    testWidgets('error ที่ไม่คาดคิด แสดงข้อความทั่วไป', (tester) async {
      final repo = _FakeBorrowRepo()..createError = StateError('boom');
      await _show(tester, repo);
      await _fillPurpose(tester, 'ถ่ายกิจกรรม');
      await _goNextMonth(tester);
      await _tapDay(tester, 10);
      await _tapDay(tester, 11);

      await tester.tap(_submitButton());
      await tester.pumpAndSettle();

      expect(find.text('ส่งคำขอไม่สำเร็จ กรุณาลองอีกครั้ง'), findsOneWidget);
    });
  });

  group('BorrowRequestPage โหลดปฏิทินไม่สำเร็จ', () {
    testWidgets('แสดงข้อความ error และปุ่มลองอีกครั้ง ซึ่งโหลดใหม่ได้', (tester) async {
      final repo = _FakeBorrowRepo()..fetchError = const ApiException('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้');
      await _show(tester, repo);

      expect(find.text('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้'), findsOneWidget);
      expect(find.text('ลองอีกครั้ง'), findsOneWidget);
      expect(find.text('จ'), findsNothing); // ไม่มีปฏิทิน

      repo.fetchError = null;
      await tester.tap(find.text('ลองอีกครั้ง'));
      await tester.pumpAndSettle();

      expect(find.text('เชื่อมต่อเซิร์ฟเวอร์ไม่ได้'), findsNothing);
      expect(find.text('จ'), findsOneWidget);
    });

    testWidgets('error ที่ไม่คาดคิด แสดง "โหลดปฏิทินไม่สำเร็จ"', (tester) async {
      final repo = _FakeBorrowRepo()..fetchError = StateError('boom');
      await _show(tester, repo);

      expect(find.text('โหลดปฏิทินไม่สำเร็จ'), findsOneWidget);
    });
  });
}
