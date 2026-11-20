import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/equipment_ui.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/home/equipment_card.dart';
import 'package:frontend/features/home/equipment_repository.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _pumpCard(
  WidgetTester tester,
  Equipment equipment, {
  required VoidCallback onTap,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 180,
            height: EquipmentCard.height,
            child: EquipmentCard(
              equipment: equipment,
              selected: false,
              onTap: onTap,
            ),
          ),
        ),
      ),
    ),
  );
}

String _statusLabel(EquipmentStatus status) => switch (status) {
  EquipmentStatus.available => 'ว่าง',
  EquipmentStatus.borrowed => 'ถูกเช่าอยู่',
  EquipmentStatus.maintenance => 'ซ่อมบำรุง',
  EquipmentStatus.lost => 'สูญหาย',
};

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders equipment loaded from the real backend', (tester) async {
    final equipment = await ApiEquipmentRepository(ApiClient())
        .fetchEquipment();
    expect(
      equipment,
      isNotEmpty,
      reason: 'The backend returned no equipment to display.',
    );

    for (final item in equipment) {
      var tapped = false;
      await _pumpCard(tester, item, onTap: () => tapped = true);

      expect(find.text(item.name), findsOneWidget);
      expect(find.text(item.assetCode), findsOneWidget);
      expect(find.text(rentalPriceLabel(item)), findsOneWidget);
      expect(find.text(depositLabel(item)), findsOneWidget);
      expect(find.text(_statusLabel(item.status)), findsOneWidget);

      final imageUrl = item.imageUrl?.trim();
      if (imageUrl == null || imageUrl.isEmpty) {
        expect(find.byType(Image), findsNothing);
        expect(find.byIcon(categoryIcon(item.categoryName)), findsOneWidget);
      } else {
        final image = tester.widget<Image>(find.byType(Image));
        final imageProvider = image.image;
        if (imageProvider is! NetworkImage) {
          fail('Equipment image is not using a network image provider.');
        }
        final expectedUrl = imageUrl.startsWith('http')
            ? imageUrl
            : '$kApiBaseUrl${imageUrl.startsWith('/') ? '' : '/'}$imageUrl';
        expect(imageProvider.url, expectedUrl);
      }

      await tester.tap(find.byType(EquipmentCard));
      expect(
        tapped,
        item.selectable,
        reason: '${item.assetCode} should follow its availability status.',
      );
    }
  });
}
