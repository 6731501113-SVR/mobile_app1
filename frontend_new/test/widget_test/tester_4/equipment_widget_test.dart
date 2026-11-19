import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'dart:async';

import 'package:frontend/features/admin/data/admin_equipment.dart';
import 'package:frontend/features/admin/data/api_repository.dart';
import 'package:frontend/features/admin/screens/admin_equipment_screen.dart';
import 'package:frontend/features/admin/screens/category_form_screen.dart';
import 'package:frontend/features/admin/screens/equipment_form_screen.dart';

class MockApiRepository extends Mock implements ApiRepository {}

void main() {
  late MockApiRepository mockRepo;

  final cam = Equipment(
    id: 1,
    assetCode: 'CAM-001',
    name: 'Canon R6',
    categoryId: 1,
    categoryName: 'กล้อง',
    status: 'available',
    pricePerDay: 60,
    deposit: 500,
    stock: 1,
  );
  final mic = Equipment(
    id: 2,
    assetCode: 'MIC-001',
    name: 'Rode Mic',
    categoryId: 2,
    categoryName: 'เสียง',
    status: 'borrowed',
    pricePerDay: 40,
    deposit: 300,
    stock: 1,
  );
  final radio = Equipment(
    id: 3,
    assetCode: 'RAD-001',
    name: 'Radio X',
    categoryId: 3,
    categoryName: 'วิทยุ',
    status: 'maintenance',
    pricePerDay: 20,
    deposit: 100,
    stock: 1,
  );

  setUpAll(() {
    // ค่า fallback สำหรับ type ที่เราสร้างเองเมื่อใช้ any()/captureAny()
    registerFallbackValue(cam);
  });

  setUp(() {
    mockRepo = MockApiRepository();
    // ค่าเริ่มต้นของทุกเทสต์ (เทสต์ไหนอยากเปลี่ยนก็ when() ทับได้)
    when(() => mockRepo.getEquipmentList())
        .thenAnswer((_) async => [cam, mic, radio]);
    when(() => mockRepo.getCategories()).thenAnswer(
      (_) async => <Map<String, dynamic>>[
        {'id': 1, 'name': 'กล้อง'},
        {'id': 2, 'name': 'เสียง'},
      ],
    );
    when(
      () => mockRepo.saveEquipmentWithImage(
        any(),
        imageFile: any(named: 'imageFile'),
        isUpdate: any(named: 'isUpdate'),
      ),
    ).thenAnswer((_) async => true);
    when(() => mockRepo.saveCategory(any())).thenAnswer((_) async => true);
    when(() => mockRepo.deleteEquipment(any())).thenAnswer((_) async => true);
  });

  // ---------------------------------------------------------------------
  // 1. หน้าจัดการอุปกรณ์
  // ---------------------------------------------------------------------
  testWidgets('1.Equipment list should show all equipment from backend.', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminEquipmentScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    verify(() => mockRepo.getEquipmentList()).called(1);
    expect(find.byType(ListTile), findsNWidgets(3));
    expect(find.text('Canon R6'), findsOneWidget);
    expect(find.text('Rode Mic'), findsOneWidget);
    expect(find.textContaining('CAM-001'), findsOneWidget);
    expect(find.textContaining('60.0 บาท/วัน'), findsOneWidget);
    expect(find.textContaining('มัดจำ 500.0 บาท'), findsOneWidget);
  });

  testWidgets('2.Each equipment should show its own status.', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminEquipmentScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Canon R6'),
        matching: find.textContaining('พร้อมใช้งาน'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Rode Mic'),
        matching: find.textContaining('ถูกยืม'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Radio X'),
        matching: find.textContaining('ซ่อมบำรุง'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('3.Add button should open the equipment form in create mode.', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminEquipmentScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'เพิ่มอุปกรณ์'));
    await tester.pumpAndSettle();

    expect(find.byType(EquipmentFormScreen), findsOneWidget);
    expect(find.text('เพิ่มอุปกรณ์ใหม่'), findsOneWidget);
  });

  testWidgets(
    '4.Equipment list should show error and retry when loading fails.',
    (WidgetTester tester) async {
      when(() => mockRepo.getEquipmentList())
          .thenAnswer((_) async => throw Exception('load failed'));

      await tester.pumpWidget(
        MaterialApp(home: AdminEquipmentScreen(repository: mockRepo)),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('โหลดรายการอุปกรณ์ไม่สำเร็จ'), findsOneWidget);

      // retry สำเร็จ
      when(() => mockRepo.getEquipmentList()).thenAnswer((_) async => [cam]);
      await tester.tap(find.text('ลองอีกครั้ง'));
      await tester.pumpAndSettle();

      expect(find.text('Canon R6'), findsOneWidget);
    },
  );

  testWidgets(
    '5.Equipment list should show empty message when there is no equipment.',
    (WidgetTester tester) async {
      when(() => mockRepo.getEquipmentList()).thenAnswer((_) async => []);

      await tester.pumpWidget(
        MaterialApp(home: AdminEquipmentScreen(repository: mockRepo)),
      );
      await tester.pumpAndSettle();

      expect(find.text('ยังไม่มีอุปกรณ์'), findsOneWidget);
    },
  );

  // ---------------------------------------------------------------------
  // 2. ฟอร์มอุปกรณ์
  // ---------------------------------------------------------------------
  testWidgets('6.Empty required fields should show errors and not save.', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: EquipmentFormScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'เพิ่มอุปกรณ์'));
    await tester.pumpAndSettle();

    expect(find.text('กรุณากรอกรหัสสินทรัพย์'), findsOneWidget);
    expect(find.text('กรุณากรอกชื่ออุปกรณ์'), findsOneWidget);
    expect(find.text('กรุณาเลือกหมวดหมู่'), findsOneWidget);
    verifyNever(
      () => mockRepo.saveEquipmentWithImage(
        any(),
        imageFile: any(named: 'imageFile'),
        isUpdate: any(named: 'isUpdate'),
      ),
    );
  });

  testWidgets('7.Valid input should save equipment and go back to the list.', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: AdminEquipmentScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'เพิ่มอุปกรณ์'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'รหัสสินทรัพย์ (Asset Code)'),
      'NEW-001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ชื่ออุปกรณ์'),
      'Sony A7',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ราคาเช่าต่อวัน (บาท)'),
      '80',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'เงินมัดจำ (บาท)'),
      '700',
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('กล้อง').last);
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'เพิ่มอุปกรณ์'));
    await tester.pumpAndSettle();

    // saveEquipmentWithImage ถูกเรียกด้วยข้อมูลที่กรอก (โหมดสร้างใหม่)
    final saved =
        verify(
              () => mockRepo.saveEquipmentWithImage(
                captureAny(),
                imageFile: any(named: 'imageFile'),
                isUpdate: false,
              ),
            ).captured.single
            as Equipment;
    expect(saved.assetCode, 'NEW-001');
    expect(saved.name, 'Sony A7');
    expect(saved.categoryId, 1);
    expect(saved.pricePerDay, 80.0);
    expect(saved.deposit, 700.0);

    // กลับไปหน้ารายการ และโหลดรายการใหม่
    expect(find.byType(EquipmentFormScreen), findsNothing);
    expect(find.text('จัดการอุปกรณ์'), findsOneWidget);
    verify(() => mockRepo.getEquipmentList()).called(2);
  });

  testWidgets('8.Edit mode should show the existing equipment data.', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: AdminEquipmentScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Canon R6'));
    await tester.pumpAndSettle();

    expect(find.text('แก้ไขอุปกรณ์'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'CAM-001'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Canon R6'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '60.0'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '500.0'), findsOneWidget);

    // แก้ชื่อแล้วบันทึก → isUpdate ต้องเป็น true
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Canon R6'),
      'Canon R6 II',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'บันทึกการแก้ไข'));
    await tester.pumpAndSettle();

    final saved =
        verify(
              () => mockRepo.saveEquipmentWithImage(
                captureAny(),
                imageFile: any(named: 'imageFile'),
                isUpdate: true,
              ),
            ).captured.single
            as Equipment;
    expect(saved.id, 1);
    expect(saved.name, 'Canon R6 II');
  });

  testWidgets('9.Image button should show gallery and camera options.', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: EquipmentFormScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.image), findsOneWidget); // ยังไม่มีรูป

    await tester.tap(find.text('เพิ่ม / เปลี่ยนรูปภาพ'));
    await tester.pumpAndSettle();

    expect(find.text('เลือกจากคลังภาพ (Gallery)'), findsOneWidget);
    expect(find.text('ถ่ายภาพด้วยกล้อง (Camera)'), findsOneWidget);
  });

  testWidgets('10.Saving without an image should send imageFile as null.', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: EquipmentFormScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'รหัสสินทรัพย์ (Asset Code)'),
      'NEW-001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ชื่ออุปกรณ์'),
      'Sony A7',
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('กล้อง').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'เพิ่มอุปกรณ์'));
    await tester.pump();
    await tester.pump();

    verify(
      () => mockRepo.saveEquipmentWithImage(
        any(),
        imageFile: null,
        isUpdate: false,
      ),
    ).called(1);
  });

  // ---------------------------------------------------------------------
  // 3. ฟอร์มหมวดหมู่
  // ---------------------------------------------------------------------
  testWidgets('11.Category form should show a name field and a save button.', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CategoryFormScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('ชื่อหมวดหมู่ (Category Name)'), findsOneWidget);
    expect(
      find.widgetWithText(ElevatedButton, 'บันทึกหมวดหมู่'),
      findsOneWidget,
    );
  });

  testWidgets(
    '12.Saving a new category should send the name and show success.',
    (WidgetTester tester) async {
      // เปิดฟอร์มจากอีกหน้า เพื่อให้ Navigator.pop ทำงานได้
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            // ต้องมี Scaffold ที่หน้าเริ่มต้น ไม่งั้น Snackbar จะไม่มีที่แสดงหลังปิดฟอร์ม
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CategoryFormScreen(repository: mockRepo),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'อุปกรณ์เครือข่าย');
      await tester.tap(find.widgetWithText(ElevatedButton, 'บันทึกหมวดหมู่'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.saveCategory('อุปกรณ์เครือข่าย')).called(1);
      expect(find.text('เพิ่มหมวดหมู่สำเร็จ'), findsOneWidget);
      expect(find.byType(CategoryFormScreen), findsNothing);
    },
  );

  testWidgets('13.Empty category name should show a warning and not save.', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: CategoryFormScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'บันทึกหมวดหมู่'));
    await tester.pumpAndSettle();

    expect(find.text('กรุณากรอกชื่อหมวดหมู่'), findsOneWidget);
    verifyNever(() => mockRepo.saveCategory(any()));
  });

  // ---------------------------------------------------------------------
  // 4. Error handling
  // ---------------------------------------------------------------------
  testWidgets('14.Error when saving equipment should show a snackbar.', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    when(
      () => mockRepo.saveEquipmentWithImage(
        any(),
        imageFile: any(named: 'imageFile'),
        isUpdate: any(named: 'isUpdate'),
      ),
    ).thenAnswer((_) async => throw Exception('เซิร์ฟเวอร์ขัดข้อง'));

    await tester.pumpWidget(
      MaterialApp(home: EquipmentFormScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'รหัสสินทรัพย์ (Asset Code)'),
      'NEW-001',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'ชื่ออุปกรณ์'),
      'Sony A7',
    );
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('กล้อง').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'เพิ่มอุปกรณ์'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('เซิร์ฟเวอร์ขัดข้อง'), findsOneWidget);
    expect(find.byType(EquipmentFormScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('15.Failed save of category should show a snackbar.', (
    WidgetTester tester,
  ) async {
    when(() => mockRepo.saveCategory(any())).thenAnswer((_) async => false);

    await tester.pumpWidget(
      MaterialApp(home: CategoryFormScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'อุปกรณ์เครือข่าย');
    await tester.tap(find.widgetWithText(ElevatedButton, 'บันทึกหมวดหมู่'));
    await tester.pumpAndSettle();

    expect(find.text('เพิ่มหมวดหมู่ไม่สำเร็จ'), findsOneWidget);
    expect(find.byType(CategoryFormScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('16.Exception when saving category should show a snackbar.', (
    WidgetTester tester,
  ) async {
    when(() => mockRepo.saveCategory(any()))
        .thenAnswer((_) async => throw Exception('network error'));

    await tester.pumpWidget(
      MaterialApp(home: CategoryFormScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'อุปกรณ์เครือข่าย');
    await tester.tap(find.widgetWithText(ElevatedButton, 'บันทึกหมวดหมู่'));
    await tester.pumpAndSettle();

    expect(find.textContaining('เกิดข้อผิดพลาด'), findsOneWidget);
    expect(find.byType(CategoryFormScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    '17.confirmation should delete the equipment and reload the list.',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: AdminEquipmentScreen(repository: mockRepo)),
      );
      await tester.pumpAndSettle();

      // กดปุ่มลบของ Canon R6 (id 1)
      await tester.tap(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Canon R6'),
          matching: find.byIcon(Icons.delete_outline),
        ),
      );
      await tester.pumpAndSettle();

      // มี dialog ยืนยัน
      expect(find.text('ยืนยันการลบอุปกรณ์'), findsOneWidget);
      expect(find.textContaining('ต้องการลบ "Canon R6"'), findsOneWidget);
      expect(find.textContaining('ประวัติการยืมจะยังคงอยู่'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'ลบอุปกรณ์'));
      await tester.pumpAndSettle();

      verify(() => mockRepo.deleteEquipment(1)).called(1);
      verify(() => mockRepo.getEquipmentList()).called(2);
      expect(find.text('ลบ "Canon R6" สำเร็จ'), findsOneWidget);
    },
  );

  testWidgets('18. cancelling should not delete anything.', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: AdminEquipmentScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Canon R6'),
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('ยกเลิก'));
    await tester.pumpAndSettle();

    verifyNever(() => mockRepo.deleteEquipment(any()));
    expect(find.text('ยืนยันการลบอุปกรณ์'), findsNothing);
    expect(find.text('Canon R6'), findsOneWidget);
  });

  testWidgets('19.should show a spinner on that item while deleting.', (
    WidgetTester tester,
  ) async {
    // ทำให้การลบ "ค้าง" ไว้ก่อน จนกว่าเราจะสั่ง complete()
    final completer = Completer<void>();
    when(() => mockRepo.deleteEquipment(any()))
        .thenAnswer((_) => completer.future);

    await tester.pumpWidget(
      MaterialApp(home: AdminEquipmentScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    final canonTile = find.widgetWithText(ListTile, 'Canon R6');
    expect(
      find.descendant(
        of: canonTile,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsNothing,
    );

    await tester.tap(
      find.descendant(
        of: canonTile,
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ลบอุปกรณ์'));
    await tester.pump(); // เดินเฟรมเดียว ยังไม่รอให้ลบเสร็จ

    // ระหว่างลบ: ไอคอนถังขยะของแถวนั้นกลายเป็นวงกลมหมุน
    expect(
      find.descendant(
        of: canonTile,
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );

    completer.complete();
    await tester.pumpAndSettle();

    expect(find.text('ลบ "Canon R6" สำเร็จ'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('20. backend error should show a snackbar and keep the item.', (
    WidgetTester tester,
  ) async {
    when(() => mockRepo.deleteEquipment(any()))
        .thenAnswer((_) async => throw Exception('เซิร์ฟเวอร์ขัดข้อง'));

    await tester.pumpWidget(
      MaterialApp(home: AdminEquipmentScreen(repository: mockRepo)),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, 'Canon R6'),
        matching: find.byIcon(Icons.delete_outline),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'ลบอุปกรณ์'));
    await tester.pumpAndSettle();

    expect(find.textContaining('ลบอุปกรณ์ไม่สำเร็จ'), findsOneWidget);
    expect(find.text('Canon R6'), findsOneWidget);
    verify(() => mockRepo.getEquipmentList())
        .called(1); // ไม่โหลดซ้ำเมื่อลบไม่สำเร็จ
  });
}
