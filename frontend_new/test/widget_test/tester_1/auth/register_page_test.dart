import 'dart:async';

import '../helpers/app_exception.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/auth/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/widget_helpers.dart';

/// Opens the register page from a button, like the login page does, and
/// remembers what the page returned when it closed.
class _Host extends StatefulWidget {
  const _Host({required this.repo, required this.onResult});

  final FakeAuthRepository repo;
  final void Function(AppUser? user) onResult;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  Future<void> _open() async {
    final user = await Navigator.of(context).push<AppUser>(
      MaterialPageRoute(builder: (_) => RegisterPage(repo: widget.repo)),
    );
    widget.onResult(user);
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: ElevatedButton(onPressed: _open, child: const Text('open'))));
}

void main() {
  late FakeAuthRepository repo;

  setUp(() => repo = FakeAuthRepository());

  // Field order: 0 student id, 1 full name, 2 password, 3 confirm password.
  Finder field(int index) => find.byType(TextFormField).at(index);
  Finder createButton() => find.widgetWithText(FilledButton, 'สร้างบัญชี');
  String textOf(WidgetTester tester, int index) =>
      tester.widget<TextFormField>(field(index)).controller!.text;

  Future<void> pumpRegister(WidgetTester tester) =>
      pumpApp(tester, RegisterPage(repo: repo));

  Future<void> fillValid(WidgetTester tester, {String confirm = 'secret123'}) async {
    await tester.enterText(field(0), '6731500002');
    await tester.enterText(field(1), '  มาลี รักเรียน ');
    await tester.enterText(field(2), 'secret123');
    await tester.enterText(field(3), confirm);
  }

  group('layout', () {
    testWidgets('shows the form, the hint and the Argon2id note', (tester) async {
      await pumpRegister(tester);

      expect(find.text('สมัครสมาชิก'), findsOneWidget);
      expect(find.text('สร้างบัญชีผู้เช่าเพื่อจองอุปกรณ์สำหรับกิจกรรมของคุณ'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(find.text('รหัสผ่านจะถูกเข้ารหัสด้วย Argon2id ก่อนเก็บลงระบบ'), findsOneWidget);
      expect(createButton(), findsOneWidget);
    });

    testWidgets('has no role field and no old "ยืม" wording', (tester) async {
      await pumpRegister(tester);

      expect(find.textContaining('role', findRichText: true), findsNothing);
      expect(find.textContaining('สิทธิ์'), findsNothing);
      expect(find.textContaining('ยืม'), findsNothing);
    });

    testWidgets('the eye icon shows or hides both password fields together', (tester) async {
      await pumpRegister(tester);
      bool hidden(int i) => tester.widget<TextField>(find.byType(TextField).at(i)).obscureText;

      expect([hidden(2), hidden(3)], [true, true]);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect([hidden(2), hidden(3)], [false, false]);
    });
  });

  group('student id field', () {
    testWidgets('accepts digits only, at most 10', (tester) async {
      await pumpRegister(tester);

      await tester.enterText(field(0), '67a3150108799');

      expect(textOf(tester, 0), '6731501087');
    });
  });

  group('validation', () {
    testWidgets('an empty form flags the required fields and sends nothing', (tester) async {
      await pumpRegister(tester);

      await tester.tap(createButton());
      await tester.pump();

      expect(find.text('กรุณากรอกรหัสนักศึกษา'), findsOneWidget);
      expect(find.text('กรุณากรอกชื่อ-นามสกุล'), findsOneWidget);
      expect(find.text('รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร'), findsOneWidget);
      expect(repo.registerCalls, isEmpty);
    });

    testWidgets('a short student id is flagged', (tester) async {
      await pumpRegister(tester);
      await fillValid(tester);

      await tester.enterText(field(0), '12345');
      await tester.tap(createButton());
      await tester.pump();

      expect(find.text('รหัสนักศึกษาต้องมี 10 หลัก'), findsOneWidget);
      expect(repo.registerCalls, isEmpty);
    });

    testWidgets('a short password is flagged', (tester) async {
      await pumpRegister(tester);
      await fillValid(tester);

      await tester.enterText(field(2), 'short');
      await tester.enterText(field(3), 'short');
      await tester.tap(createButton());
      await tester.pump();

      expect(find.text('รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร'), findsOneWidget);
      expect(repo.registerCalls, isEmpty);
    });

    testWidgets('a different confirmation is flagged', (tester) async {
      await pumpRegister(tester);
      await fillValid(tester, confirm: 'different1');

      await tester.tap(createButton());
      await tester.pump();

      expect(find.text('รหัสผ่านไม่ตรงกัน'), findsOneWidget);
      expect(repo.registerCalls, isEmpty);
    });
  });

  group('submitting', () {
    testWidgets('sends trimmed details (and no role) then closes with the new user', (tester) async {
      AppUser? result;
      var closed = false;
      useTallScreen(tester);
      await tester.pumpWidget(MaterialApp(
        home: _Host(
          repo: repo,
          onResult: (u) {
            result = u;
            closed = true;
          },
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await fillValid(tester);
      await tester.tap(createButton());
      await tester.pumpAndSettle();

      final call = repo.registerCalls.single;
      expect(call.username, '6731500002');
      expect(call.fullName, 'มาลี รักเรียน');
      expect(call.password, 'secret123');
      expect(closed, isTrue);
      expect(result, same(repo.user));
      expect(createButton(), findsNothing);
    });

    testWidgets('shows the server message and stays open when it fails', (tester) async {
      repo.error = const AppException('รหัสนักศึกษานี้ถูกใช้งานแล้ว');
      await pumpRegister(tester);
      await fillValid(tester);

      await tester.tap(createButton());
      await tester.pumpAndSettle();

      expect(find.text('รหัสนักศึกษานี้ถูกใช้งานแล้ว'), findsOneWidget);
      expect(createButton(), findsOneWidget);
    });

    testWidgets('shows a spinner and disables the button while waiting', (tester) async {
      repo.gate = Completer<void>();
      await pumpRegister(tester);
      await fillValid(tester);

      await tester.tap(createButton());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

      repo.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('leaving', () {
    testWidgets('the back arrow and "เข้าสู่ระบบ" close the page without a user', (tester) async {
      for (final leave in <Finder>[
        find.byTooltip('กลับ'),
        find.widgetWithText(TextButton, 'เข้าสู่ระบบ'),
      ]) {
        final results = <AppUser?>[];
        useTallScreen(tester);
        await tester.pumpWidget(MaterialApp(home: _Host(repo: repo, onResult: results.add)));
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        await tester.tap(leave);
        await tester.pumpAndSettle();

        expect(results, [null]);
        expect(repo.registerCalls, isEmpty);
      }
    });
  });
}
