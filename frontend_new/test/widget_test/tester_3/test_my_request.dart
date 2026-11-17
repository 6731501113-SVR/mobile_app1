import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/borrow/borrow_models.dart';
import 'package:frontend/features/borrow/borrow_repository.dart';
import 'package:frontend/features/borrow/my_requests_page.dart';
import 'package:mocktail/mocktail.dart';

class MockBorrowRepository extends Mock implements BorrowRepository {}

MockBorrowRepository _repository() {
  final repo = MockBorrowRepository();
  when(() => repo.fetchMine(tab: any(named: 'tab')))
      .thenAnswer((invocation) async {
        final tab = invocation.namedArguments[#tab] as String;
        return tab == 'history' ? <BorrowRequest>[] : [_request()];
      });
  when(() => repo.cancel(any())).thenAnswer((_) async => _request());
  return repo;
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

Widget _page(MockBorrowRepository repo) => MaterialApp(
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
      final repo = _repository();

      await tester.pumpWidget(_page(repo));
      await tester.pumpAndSettle();

      expect(find.text('รายการเช่าของฉัน'), findsOneWidget);
      expect(find.text('กล้อง Canon'), findsOneWidget);
      expect(find.text('CAM-008 · ทำโครงงาน'), findsOneWidget);
      expect(find.text('รออนุมัติ'), findsNWidgets(2));
      verify(() => repo.fetchMine(tab: 'all')).called(1);
    });

    testWidgets('switches tabs and shows the empty state', (tester) async {
      final repo = _repository();

      await tester.pumpWidget(_page(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ประวัติ'));
      await tester.pumpAndSettle();

      verify(() => repo.fetchMine(tab: 'all')).called(1);
      verify(() => repo.fetchMine(tab: 'history')).called(1);
      expect(find.text('ยังไม่มีรายการเช่า'), findsOneWidget);
    });

    testWidgets('asks for confirmation before cancelling a request', (
      tester,
    ) async {
      final repo = _repository();

      await tester.pumpWidget(_page(repo));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยกเลิกคำขอ'));
      await tester.pumpAndSettle();

      expect(find.text('ยกเลิกคำขอนี้?'), findsOneWidget);
      await tester.tap(find.text('ไม่ยกเลิก'));
      await tester.pumpAndSettle();
      verifyNever(() => repo.cancel(any()));

      await tester.tap(find.text('ยกเลิกคำขอ'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ยกเลิกคำขอ').last);
      await tester.pumpAndSettle();

      verify(() => repo.cancel(8)).called(1);
    });
  });
}
