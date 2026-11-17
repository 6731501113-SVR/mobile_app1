import 'dart:async';

import '../helpers/app_exception.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/auth/login_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/widget_helpers.dart';

void main() {
  late FakeAuthRepository repo;
  late List<AppUser> signedIn;

  setUp(() {
    repo = FakeAuthRepository();
    signedIn = [];
  });

  Future<void> pumpLogin(WidgetTester tester) =>
      pumpApp(tester, LoginPage(repo: repo, onLoggedIn: signedIn.add));

  // Field order on the page: 0 = student id / username, 1 = password.
  Finder field(int index) => find.byType(TextFormField).at(index);
  Finder loginButton() => find.widgetWithText(FilledButton, 'เข้าสู่ระบบ');

  Future<void> fillAndSubmit(WidgetTester tester) async {
    await tester.enterText(field(0), '  6731501087 ');
    await tester.enterText(field(1), 'secret123');
    await tester.tap(loginButton());
  }

  group('layout', () {
    testWidgets('shows the title, both fields, the button and the sign-up link', (tester) async {
      await pumpLogin(tester);

      expect(find.text('ระบบเช่า-คืนครุภัณฑ์'), findsOneWidget);
      expect(find.text('รหัสนักศึกษา / ไอดีผู้ใช้'), findsOneWidget);
      expect(find.text('รหัสผ่าน'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(loginButton(), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'สมัครสมาชิก'), findsOneWidget);
    });

    testWidgets('has no demo-account box and no old "ยืม" wording', (tester) async {
      await pumpLogin(tester);

      expect(find.textContaining('password123'), findsNothing);
      expect(find.textContaining('admin1234'), findsNothing);
      expect(find.textContaining('ทดลอง'), findsNothing);
      expect(find.textContaining('demo', findRichText: true), findsNothing);
      expect(find.textContaining('ยืม'), findsNothing);
    });

    testWidgets('the password is hidden until the eye icon is tapped', (tester) async {
      await pumpLogin(tester);
      bool hidden() => tester.widget<TextField>(find.byType(TextField).at(1)).obscureText;

      expect(hidden(), isTrue);

      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();
      expect(hidden(), isFalse);

      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();
      expect(hidden(), isTrue);
    });
  });

  group('validation', () {
    testWidgets('empty fields show both messages and never call the repository', (tester) async {
      await pumpLogin(tester);

      await tester.tap(loginButton());
      await tester.pump();

      expect(find.text('กรุณากรอกรหัสนักศึกษา'), findsOneWidget);
      expect(find.text('กรุณากรอกรหัสผ่าน'), findsOneWidget);
      expect(repo.loginCalls, isEmpty);
      expect(signedIn, isEmpty);
    });

    testWidgets('only the missing field is flagged', (tester) async {
      await pumpLogin(tester);

      await tester.enterText(field(0), '6731501087');
      await tester.tap(loginButton());
      await tester.pump();

      expect(find.text('กรุณากรอกรหัสนักศึกษา'), findsNothing);
      expect(find.text('กรุณากรอกรหัสผ่าน'), findsOneWidget);
    });
  });

  group('signing in', () {
    testWidgets('sends the trimmed username and reports the signed-in user', (tester) async {
      await pumpLogin(tester);

      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(repo.loginCalls.single.username, '6731501087');
      expect(repo.loginCalls.single.password, 'secret123');
      expect(signedIn, [repo.user]);
    });

    testWidgets('shows the error message and does not sign in when it fails', (tester) async {
      repo.error = const AppException('รหัสนักศึกษาหรือรหัสผ่านไม่ถูกต้อง');
      await pumpLogin(tester);

      await fillAndSubmit(tester);
      await tester.pumpAndSettle();

      expect(find.text('รหัสนักศึกษาหรือรหัสผ่านไม่ถูกต้อง'), findsOneWidget);
      expect(signedIn, isEmpty);
    });

    testWidgets('shows a spinner and disables the button while waiting', (tester) async {
      repo.gate = Completer<void>();
      await pumpLogin(tester);

      await fillAndSubmit(tester);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      expect(repo.loginCalls, hasLength(1));

      repo.gate!.complete();
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(signedIn, hasLength(1));
    });

    testWidgets('a failed attempt can be retried and the error goes away', (tester) async {
      repo.error = const AppException('ผิดพลาด');
      await pumpLogin(tester);
      await fillAndSubmit(tester);
      await tester.pumpAndSettle();
      expect(find.text('ผิดพลาด'), findsOneWidget);

      repo.error = null;
      await tester.tap(loginButton());
      await tester.pumpAndSettle();

      expect(find.text('ผิดพลาด'), findsNothing);
      expect(signedIn, hasLength(1));
    });
  });

  group('sign-up link', () {
    testWidgets('opens the sign-up page', (tester) async {
      await pumpLogin(tester);

      await tester.tap(find.widgetWithText(TextButton, 'สมัครสมาชิก'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'สร้างบัญชี'), findsOneWidget);
    });

    testWidgets('a successful sign-up signs the new user in', (tester) async {
      await pumpLogin(tester);
      await tester.tap(find.widgetWithText(TextButton, 'สมัครสมาชิก'));
      await tester.pumpAndSettle();

      // Register page fields: 0 student id, 1 name, 2 password, 3 confirm.
      await tester.enterText(field(0), '6731500002');
      await tester.enterText(field(1), 'มาลี รักเรียน');
      await tester.enterText(field(2), 'secret123');
      await tester.enterText(field(3), 'secret123');
      await tester.tap(find.widgetWithText(FilledButton, 'สร้างบัญชี'));
      await tester.pumpAndSettle();

      expect(repo.registerCalls.single.username, '6731500002');
      expect(signedIn, [repo.user]);
      expect(find.widgetWithText(FilledButton, 'สร้างบัญชี'), findsNothing); // back on login
    });

    testWidgets('going back from sign-up signs nobody in', (tester) async {
      await pumpLogin(tester);
      await tester.tap(find.widgetWithText(TextButton, 'สมัครสมาชิก'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('กลับ'));
      await tester.pumpAndSettle();

      expect(signedIn, isEmpty);
      expect(loginButton(), findsOneWidget);
    });
  });
}
