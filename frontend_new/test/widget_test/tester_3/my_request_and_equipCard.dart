import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/borrow/borrow_models.dart';
import 'package:frontend/features/borrow/borrow_repository.dart';
import 'package:frontend/features/borrow/my_requests_page.dart';
import 'package:frontend/features/home/equipment_card.dart';

import '../../unit_test/helpers/fakes.dart';

class _FakeBorrowRepository implements BorrowRepository {
  _FakeBorrowRepository(this.items);

  final List<BorrowRequest> items;
  final requestedTabs = <String>[];
  final cancelledIds = <int>[];

  @override
  Future<List<BorrowRequest>> fetchMine({String tab = 'all'}) async {
    requestedTabs.add(tab);
    if (tab == 'history') return const [];
    return items;
  }

  @override
  Future<BorrowRequest> cancel(int id) async {
    cancelledIds.add(id);
    return items.first;
  }

  @override
  Future<List<BorrowRequest>> create({
    required List<int> equipmentIds,
    required String purpose,
    required DateTime start,
    required DateTime end,
  }) async => items;

  @override
  Future<List<DateRange>> fetchBookedRanges(int equipmentId) async => const [];

  @override
  Future<BorrowRequest> fetchOne(int id) async => items.first;

  @override
  Future<void> uploadSlip({
    required int requestId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {}
}

BorrowRequest _request() => BorrowRequest(
  id: 8,
  equipmentId: 2,
  equipmentName: 'กล้อง Canon',
  assetCode: 'CAM-008',
  purpose: 'ทำโครงงาน',
  startDate: DateTime(2026, 12, 1),
  endDate: DateTime(2026, 12, 3),
  status: RequestStatus.pending,
  lateDays: 0,
  fineAmount: 0,
  finePaid: false,
  estimatedFine: 0,
  finePerDay: 30,
);

Widget _page(_FakeBorrowRepository repo) => MaterialApp(
  home: Scaffold(
    body: MyRequestsView(
      user: const AppUser(
        id: 1,
        username: 'student',
        fullName: 'Test Student',
        role: UserRole.borrower,
      ),
      repo: repo,
    ),
  ),
);

void main() {
  group('MyRequestsView', () {
    testWidgets('loads and displays request details', (tester) async {
      final repo = _FakeBorrowRepository([_request()]);

      await tester.pumpWidget(_page(repo));
      await tester.pumpAndSettle();

      expect(find.text('รายการเช่าของฉัน'), findsOneWidget);
      expect(find.text('กล้อง Canon'), findsOneWidget);
      expect(find.text('CAM-008 · ทำโครงงาน'), findsOneWidget);
      expect(find.text('รออนุมัติ'), findsNWidgets(2));
      expect(repo.requestedTabs, ['all']);
    });

    testWidgets('switches tabs and shows the empty state', (tester) async {
      final repo = _FakeBorrowRepository([_request()]);

      await tester.pumpWidget(_page(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ประวัติ'));
      await tester.pumpAndSettle();

      expect(repo.requestedTabs, ['all', 'history']);
      expect(find.text('ยังไม่มีรายการเช่า'), findsOneWidget);
    });

    testWidgets('asks for confirmation before cancelling a request', (
      tester,
    ) async {
      final repo = _FakeBorrowRepository([_request()]);

      await tester.pumpWidget(_page(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยกเลิกคำขอ'));
      await tester.pumpAndSettle();

      expect(find.text('ยกเลิกคำขอนี้?'), findsOneWidget);
      await tester.tap(find.text('ไม่ยกเลิก'));
      await tester.pumpAndSettle();
      expect(repo.cancelledIds, isEmpty);

      await tester.tap(find.text('ยกเลิกคำขอ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยกเลิกคำขอ').last);
      await tester.pumpAndSettle();

      expect(repo.cancelledIds, [8]);
    });
  });

  group('EquipmentCard', () {
    testWidgets('shows equipment details and notifies when tapped', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: EquipmentCard.height,
              child: EquipmentCard(
                equipment: eq(
                  2,
                  name: 'กล้อง Canon',
                  code: 'CAM-002',
                  price: 250,
                ),
                selected: true,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );

      expect(find.text('กล้อง Canon'), findsOneWidget);
      expect(find.text('CAM-002'), findsOneWidget);
      expect(find.text('฿250 / วัน'), findsOneWidget);
      expect(find.text('ว่าง'), findsOneWidget);

      await tester.tap(find.byType(EquipmentCard));
      expect(taps, 1);
    });

    testWidgets('does not notify when unavailable equipment is tapped', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 180,
              height: EquipmentCard.height,
              child: EquipmentCard(
                equipment: eq(3, status: EquipmentStatus.borrowed),
                selected: false,
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(EquipmentCard));

      expect(taps, 0);
      expect(find.text('ถูกเช่าอยู่'), findsOneWidget);
    });
  });
}
