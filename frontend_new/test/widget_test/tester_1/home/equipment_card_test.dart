import 'package:frontend/core/models.dart';
import 'package:frontend/features/home/equipment_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

Future<void> pumpCard(
  WidgetTester tester,
  Equipment e, {
  VoidCallback? onTap,
  bool selected = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 180,
            height: EquipmentCard.height,
            child: EquipmentCard(equipment: e, selected: selected, onTap: onTap ?? () {}),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('price labels', () {
    test('rental price per day', () {
      expect(rentalPriceLabel(eq(1, price: 300)), '฿300 / วัน');
      expect(rentalPriceLabel(eq(1, price: 1250)), '฿1,250 / วัน');
      expect(rentalPriceLabel(eq(1, price: 300.5)), '฿300.50 / วัน');
      expect(rentalPriceLabel(eq(1)), 'ไม่มีค่าเช่า');
    });

    test('deposit', () {
      expect(depositLabel(eq(1, deposit: 2000)), 'มัดจำ ฿2,000');
      expect(depositLabel(eq(1)), 'ไม่ต้องมัดจำ');
    });
  });

  group('EquipmentCard', () {
    testWidgets('shows name, code, price per day, deposit and status', (tester) async {
      await pumpCard(
        tester,
        eq(1, name: 'กล้อง Canon EOS M50', code: 'CAM-001', price: 300, deposit: 2000),
      );

      expect(find.text('กล้อง Canon EOS M50'), findsOneWidget);
      expect(find.text('CAM-001'), findsOneWidget);
      expect(find.text('฿300 / วัน'), findsOneWidget);
      expect(find.text('มัดจำ ฿2,000'), findsOneWidget);
      expect(find.text('ว่าง'), findsOneWidget);
    });

    testWidgets('an available card can be tapped', (tester) async {
      var taps = 0;
      await pumpCard(tester, eq(1, price: 100), onTap: () => taps++);

      await tester.tap(find.byType(EquipmentCard));

      expect(taps, 1);
    });

    testWidgets('a rented card still shows its price but cannot be tapped', (tester) async {
      var taps = 0;
      await pumpCard(
        tester,
        eq(3, price: 60, deposit: 400, status: EquipmentStatus.borrowed),
        onTap: () => taps++,
      );

      await tester.tap(find.byType(EquipmentCard));

      expect(taps, 0);
      expect(find.text('฿60 / วัน'), findsOneWidget);
      expect(find.text('ถูกเช่าอยู่'), findsOneWidget);
    });
  });
}
