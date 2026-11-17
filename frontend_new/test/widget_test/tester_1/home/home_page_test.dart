import 'dart:async';

import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/borrow/borrow.dart';
import 'package:frontend/features/home/equipment_repository.dart';
import 'package:frontend/features/home/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/widget_helpers.dart';

const _user = AppUser(
  id: 1,
  username: '6731501087',
  fullName: 'สมชาย ใจดี',
  role: UserRole.borrower,
);

// Names in SampleEquipmentData (1-4 available, 5 maintenance, 6 rented).
const canon = 'กล้อง Canon EOS M50';
const sony = 'กล้อง Sony ZV-E10';
const tripod = 'ขาตั้งกล้อง';
const mic = 'ไมค์ไร้สาย (ชุด 2 ตัว)';
const speaker = 'ลำโพงบลูทูธ'; // under maintenance
const walkie = 'วอล์กกี้ทอล์กกี้ Motorola'; // already rented

void main() {
  late EquipmentRepository repo;
  late BorrowRepository borrowRepo;
  late int logouts;

  setUp(() {
    repo = FakeEquipmentRepository(
      equipment: SampleEquipmentData.equipment,
      categories: SampleEquipmentData.categories,
    );
    borrowRepo = FakeBorrowRepository();
    logouts = 0;
  });

  Future<void> pumpHome(
    WidgetTester tester, {
    EquipmentRepository? equipmentRepo,
  }) async {
    await pumpApp(
      tester,
      HomePage(
        user: _user,
        repo: equipmentRepo ?? repo,
        borrowRepo: borrowRepo,
        onLogout: () => logouts++,
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder chip(String label) => find.widgetWithText(ChoiceChip, label);
  Finder selectionText(int n) => find.text('เลือกแล้ว $n ชิ้น');

  group('loading', () {
    testWidgets('shows a spinner until the list arrives', (tester) async {
      final slow = FakeEquipmentRepository(
        equipment: [eq(1, name: 'กล้องทดสอบ')],
      )..gate = Completer<void>();
      await pumpApp(
        tester,
        HomePage(
          user: _user,
          repo: slow,
          borrowRepo: borrowRepo,
          onLogout: () {},
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('กล้องทดสอบ'), findsNothing);

      slow.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('กล้องทดสอบ'), findsOneWidget);
    });

    testWidgets(
      'shows the error with a retry button, and retry loads the list',
      (tester) async {
        final broken = FakeEquipmentRepository(
          equipment: [eq(1, name: 'กล้องทดสอบ')],
        )..error = const ApiException('ข้อมูลยังไม่พร้อม');
        await pumpHome(tester, equipmentRepo: broken);

        expect(find.text('ข้อมูลยังไม่พร้อม'), findsOneWidget);
        expect(find.text('กล้องทดสอบ'), findsNothing);

        broken.error = null;
        await tester.tap(find.widgetWithText(OutlinedButton, 'ลองอีกครั้ง'));
        await tester.pumpAndSettle();

        expect(find.text('ข้อมูลยังไม่พร้อม'), findsNothing);
        expect(find.text('กล้องทดสอบ'), findsOneWidget);
      },
    );
  });

  group('content', () {
    testWidgets(
      'greets the user and lists every item with its price and deposit',
      (tester) async {
        await pumpHome(tester);

        expect(find.text('สวัสดี'), findsOneWidget);
        expect(find.text('สมชาย ใจดี'), findsOneWidget);
        expect(find.text('อุปกรณ์ทั้งหมด'), findsOneWidget);
        expect(find.text('6 รายการ'), findsOneWidget);
        for (final name in [canon, sony, tripod, mic, speaker, walkie]) {
          expect(find.text(name), findsOneWidget, reason: name);
        }
        expect(find.text('฿300 / วัน'), findsNWidgets(6));
        expect(find.text('มัดจำ ฿2,000'), findsNWidgets(6));
      },
    );

    testWidgets('shows a chip for every category plus "ทั้งหมด"', (
      tester,
    ) async {
      await pumpHome(tester);

      for (final label in [
        'ทั้งหมด',
        'กล้อง',
        'เครื่องเสียง',
        'วิทยุสื่อสาร',
      ]) {
        expect(chip(label), findsOneWidget, reason: label);
      }
    });

    testWidgets('uses "เช่า" wording everywhere', (tester) async {
      await pumpHome(tester);

      expect(find.textContaining('ยืม'), findsNothing);
      expect(
        find.text('ถูกเช่าอยู่'),
        findsOneWidget,
      ); // the rented walkie-talkie
    });

    testWidgets('the logout button calls onLogout', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.byTooltip('ออกจากระบบ'));

      expect(logouts, 1);
    });
  });

  group('category filter and search', () {
    testWidgets('a category chip keeps only that category', (tester) async {
      await pumpHome(tester);

      await tester.tap(chip('กล้อง'));
      await tester.pumpAndSettle();

      expect(find.text('3 รายการ'), findsOneWidget);
      for (final name in [canon, sony, tripod]) {
        expect(find.text(name), findsOneWidget, reason: name);
      }
      expect(find.text(mic), findsNothing);
      expect(find.text(walkie), findsNothing);

      await tester.tap(chip('ทั้งหมด'));
      await tester.pumpAndSettle();
      expect(find.text('6 รายการ'), findsOneWidget);
    });

    testWidgets(
      'searching by name narrows the list, and the clear button resets it',
      (tester) async {
        await pumpHome(tester);

        await tester.enterText(find.byType(TextField), 'sony');
        await tester.pumpAndSettle();

        expect(find.text('1 รายการ'), findsOneWidget);
        expect(find.text(sony), findsOneWidget);
        expect(find.text(canon), findsNothing);

        await tester.tap(find.byIcon(Icons.close));
        await tester.pumpAndSettle();

        expect(find.text('6 รายการ'), findsOneWidget);
        expect(find.byIcon(Icons.close), findsNothing);
      },
    );

    testWidgets('searching by asset code works', (tester) async {
      await pumpHome(tester);

      await tester.enterText(find.byType(TextField), 'wt-005');
      await tester.pumpAndSettle();

      expect(find.text(walkie), findsOneWidget);
      expect(find.text('1 รายการ'), findsOneWidget);
    });

    testWidgets('no match shows "ไม่พบอุปกรณ์"', (tester) async {
      await pumpHome(tester);

      await tester.enterText(find.byType(TextField), 'zzzz');
      await tester.pumpAndSettle();

      expect(find.text('ไม่พบอุปกรณ์'), findsOneWidget);
      expect(find.text('0 รายการ'), findsOneWidget);
    });
  });

  group('multi-select', () {
    testWidgets('there is no selection bar until something is selected', (
      tester,
    ) async {
      await pumpHome(tester);

      expect(find.textContaining('เลือกแล้ว'), findsNothing);
      expect(
        find.widgetWithText(FilledButton, 'เลือกวันที่เช่า'),
        findsNothing,
      );
    });

    testWidgets(
      'tapping available cards selects them one by one, tapping again unselects',
      (tester) async {
        await pumpHome(tester);

        await tester.tap(find.text(canon));
        await tester.pumpAndSettle();
        expect(selectionText(1), findsOneWidget);

        await tester.tap(find.text(sony));
        await tester.pumpAndSettle();
        expect(selectionText(2), findsOneWidget);

        await tester.tap(find.text(canon));
        await tester.pumpAndSettle();
        expect(selectionText(1), findsOneWidget);
      },
    );

    testWidgets('rented and maintenance items cannot be selected', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text(speaker));
      await tester.tap(find.text(walkie));
      await tester.pumpAndSettle();

      expect(find.textContaining('เลือกแล้ว'), findsNothing);
    });

    testWidgets('"ล้าง" empties the selection and hides the bar', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.tap(find.text(canon));
      await tester.tap(find.text(mic));
      await tester.pumpAndSettle();
      expect(selectionText(2), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'ล้าง'));
      await tester.pumpAndSettle();

      expect(find.textContaining('เลือกแล้ว'), findsNothing);
    });

    testWidgets('the selection survives changing the category filter', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.tap(find.text(canon));
      await tester.pumpAndSettle();

      await tester.tap(chip('เครื่องเสียง'));
      await tester.pumpAndSettle();
      expect(find.text(canon), findsNothing); // hidden by the filter...
      expect(selectionText(1), findsOneWidget); // ...but still selected

      await tester.tap(find.text(mic));
      await tester.pumpAndSettle();
      expect(selectionText(2), findsOneWidget);
    });
  });

  group('going to the rental page', () {
    testWidgets(
      '"เลือกวันที่เช่า" opens it with the selected items; going back keeps the selection',
      (tester) async {
        await pumpHome(tester);
        await tester.tap(find.text(canon));
        await tester.tap(find.text(sony));
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(FilledButton, 'เลือกวันที่เช่า'));
        await tester.pumpAndSettle();

        expect(find.byType(BorrowRequestPage), findsOneWidget);
        expect(find.text('อุปกรณ์ 2 ชิ้น'), findsOneWidget);
        expect(find.text(canon), findsOneWidget);
        expect(find.text(sony), findsOneWidget);
        expect(find.text(mic), findsNothing);

        await tester.tap(find.byTooltip('กลับ'));
        await tester.pumpAndSettle();

        expect(find.byType(BorrowRequestPage), findsNothing);
        expect(selectionText(2), findsOneWidget);
      },
    );
  });

  group('bottom navigation', () {
    testWidgets('"รายการของฉัน" shows my rentals, and "หน้าหลัก" goes back', (
      tester,
    ) async {
      await pumpHome(tester);

      await tester.tap(find.text('รายการของฉัน'));
      await tester.pumpAndSettle();

      expect(find.text('รายการเช่าของฉัน'), findsOneWidget);
      expect(find.text('ยังไม่มีรายการเช่า'), findsOneWidget);
      expect(find.text('อุปกรณ์ทั้งหมด'), findsNothing);

      await tester.tap(find.text('หน้าหลัก'));
      await tester.pumpAndSettle();

      expect(find.text('อุปกรณ์ทั้งหมด'), findsOneWidget);
      expect(find.text(canon), findsOneWidget);
    });

    testWidgets('the selection bar is hidden on the other tab and comes back', (
      tester,
    ) async {
      await pumpHome(tester);
      await tester.tap(find.text(canon));
      await tester.pumpAndSettle();
      expect(selectionText(1), findsOneWidget);

      await tester.tap(find.text('รายการของฉัน'));
      await tester.pumpAndSettle();
      expect(find.textContaining('เลือกแล้ว'), findsNothing);

      await tester.tap(find.text('หน้าหลัก'));
      await tester.pumpAndSettle();
      expect(selectionText(1), findsOneWidget);
    });
  });
}
