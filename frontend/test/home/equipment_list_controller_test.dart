import 'dart:async';

import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/home/equipment_list_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

List<int> ids(Iterable<Equipment> items) => items.map((e) => e.id).toList();

void main() {
  late FakeEquipmentRepository repo;
  late EquipmentListController c;

  setUp(() {
    repo = FakeEquipmentRepository(
      categories: const [
        Category(id: 1, name: 'กล้อง'),
        Category(id: 2, name: 'เครื่องเสียง'),
      ],
      equipment: [
        eq(1, name: 'กล้อง Canon EOS M50', code: 'CAM-001', categoryId: 1),
        eq(2, name: 'ไมค์ไร้สาย', code: 'MIC-003', categoryId: 2, categoryName: 'เครื่องเสียง'),
        eq(3, name: 'วอล์กกี้ทอล์กกี้', code: 'WT-005', categoryId: 3, status: EquipmentStatus.borrowed),
        eq(4, name: 'ลำโพงบลูทูธ', code: 'SPK-002', categoryId: 2, status: EquipmentStatus.maintenance),
        eq(5, name: 'กล้อง Sony ZV-E10', code: 'CAM-002', categoryId: 1),
      ],
    );
    c = EquipmentListController(repo);
  });

  tearDown(() => c.dispose());

  group('loading', () {
    test('starts in the loading state', () {
      expect(c.loading, isTrue);
      expect(c.visible, isEmpty);
    });

    test('load fills the list and categories', () async {
      await c.load();

      expect(c.loading, isFalse);
      expect(c.error, isNull);
      expect(ids(c.visible), [1, 2, 3, 4, 5]);
      expect(c.categories.map((x) => x.name), ['กล้อง', 'เครื่องเสียง']);
    });

    test('an API error is shown and a retry clears it', () async {
      repo.error = const ApiException('เซิร์ฟเวอร์ไม่ตอบสนอง');

      await c.load();
      expect(c.loading, isFalse);
      expect(c.error, 'เซิร์ฟเวอร์ไม่ตอบสนอง');
      expect(c.visible, isEmpty);

      repo.error = null;
      await c.load();
      expect(c.error, isNull);
      expect(c.visible, hasLength(5));
    });

    test('an unexpected error gives a generic message', () async {
      repo.error = StateError('boom');

      await c.load();

      expect(c.error, 'โหลดรายการอุปกรณ์ไม่สำเร็จ');
    });

    test('a failed silent refresh keeps the list on screen', () async {
      await c.load();
      repo.error = const ApiException('เครือข่ายหลุด');

      await c.load(showSpinner: false);

      expect(c.error, isNull);
      expect(c.visible, hasLength(5));
    });

    test('a failed full reload shows the error', () async {
      await c.load();
      repo.error = const ApiException('เครือข่ายหลุด');

      await c.load();

      expect(c.error, 'เครือข่ายหลุด');
    });

    test('shows the spinner again while reloading', () async {
      await c.load();
      repo.gate = Completer<void>();

      final pending = c.load();
      expect(c.loading, isTrue);

      repo.gate!.complete();
      await pending;
      expect(c.loading, isFalse);
    });

    test('finishing after dispose does not throw', () async {
      final local = EquipmentListController(repo);
      repo.gate = Completer<void>();

      final pending = local.load();
      local.dispose();
      repo.gate!.complete();

      await expectLater(pending, completes);
    });
  });

  group('filter and search', () {
    setUp(() async => c.load());

    test('category filter keeps only that category', () {
      c.selectCategory(1);
      expect(ids(c.visible), [1, 5]);

      c.selectCategory(2);
      expect(ids(c.visible), [2, 4]);

      c.selectCategory(null);
      expect(ids(c.visible), [1, 2, 3, 4, 5]);
    });

    test('search matches name or asset code, ignoring case', () {
      c.setQuery('canon');
      expect(ids(c.visible), [1]);

      c.setQuery('cam-00');
      expect(ids(c.visible), [1, 5]);

      c.setQuery('ไมค์');
      expect(ids(c.visible), [2]);
    });

    test('a blank search shows everything', () {
      c.setQuery('   ');
      expect(c.visible, hasLength(5));
    });

    test('search and category combine', () {
      c.selectCategory(1);
      c.setQuery('sony');
      expect(ids(c.visible), [5]);

      c.setQuery('ไมค์');
      expect(c.visible, isEmpty);
    });

    test('listeners are only notified when something changed', () {
      var notifications = 0;
      c.addListener(() => notifications++);

      c.setQuery('cam');
      c.setQuery('cam'); // same value
      c.selectCategory(1);
      c.selectCategory(1); // same value

      expect(notifications, 2);
    });
  });

  group('multi-select', () {
    setUp(() async => c.load());

    test('available items can be selected and unselected', () {
      c.toggle(1);
      c.toggle(2);
      expect(c.selectedCount, 2);
      expect(c.isSelected(1), isTrue);

      c.toggle(1);
      expect(c.selectedCount, 1);
      expect(c.isSelected(1), isFalse);
    });

    test('rented, maintenance and unknown items are ignored', () {
      c.toggle(3); // borrowed
      c.toggle(4); // maintenance
      c.toggle(99); // does not exist

      expect(c.selectedCount, 0);
    });

    test('the selection survives filter and search changes', () {
      c.toggle(1); // camera
      c.selectCategory(2); // now only audio items are visible
      c.toggle(2);
      c.setQuery('ไมค์');

      expect(c.selectedCount, 2);
      expect(ids(c.selectedItems), [1, 2]); // includes the hidden camera
    });

    test('clearSelection empties the basket', () {
      c.toggle(1);
      c.toggle(5);

      c.clearSelection();

      expect(c.selectedCount, 0);
      expect(c.selectedItems, isEmpty);
    });

    test('a refresh drops items that are no longer available', () async {
      c.toggle(1);
      c.toggle(2);

      repo.equipment = [
        eq(1, categoryId: 1, status: EquipmentStatus.borrowed), // got rented meanwhile
        eq(2, categoryId: 2),
      ];
      await c.load(showSpinner: false);

      expect(c.isSelected(1), isFalse);
      expect(c.isSelected(2), isTrue);
      expect(c.selectedCount, 1);
    });
  });
}
