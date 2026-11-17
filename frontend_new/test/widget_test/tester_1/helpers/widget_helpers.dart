import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Makes the test screen tall (800 x 1800) so a whole page is on screen and
/// every button can be tapped without scrolling. Restored after the test.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Shows [child] in a plain MaterialApp (default theme: tests must not load
/// the Google font used by buildTheme()).
Future<void> pumpApp(WidgetTester tester, Widget child) async {
  useTallScreen(tester);
  await tester.pumpWidget(MaterialApp(home: child));
}
