import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/core/models.dart';
import 'package:frontend/features/home/equipment_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('Equipment JSON', () {
    final json = <String, dynamic>{
      'id': 3,
      'asset_code': 'WT-005',
      'name': 'วอล์กกี้ทอล์กกี้ Motorola',
      'category_id': 3,
      'category_name': 'วิทยุสื่อสาร',
      'image_url': null,
      'price_per_day': 60.0,
      'deposit': 400.0,
      'status': 'borrowed',
      'due_date': '2026-11-02',
    };

    test('fromJson reads every field', () {
      final e = Equipment.fromJson(json);
      expect(e.id, 3);
      expect(e.assetCode, 'WT-005');
      expect(e.name, 'วอล์กกี้ทอล์กกี้ Motorola');
      expect(e.categoryId, 3);
      expect(e.categoryName, 'วิทยุสื่อสาร');
      expect(e.imageUrl, isNull);
      expect(e.pricePerDay, 60);
      expect(e.deposit, 400);
      expect(e.status, EquipmentStatus.borrowed);
      expect(e.dueDate, DateTime(2026, 11, 2));
    });

    test('toJson(fromJson(x)) gives back x', () {
      expect(Equipment.fromJson(json).toJson(), json);
    });

    test('integer prices from the server are accepted', () {
      final e = Equipment.fromJson({...json, 'price_per_day': 60, 'deposit': 400});
      expect(e.pricePerDay, 60.0);
      expect(e.deposit, 400.0);
    });

    test('decimal strings from MySQL are accepted', () {
      final e = Equipment.fromJson({
        ...json,
        'price_per_day': '60.00',
        'deposit': '400.00',
      });
      expect(e.pricePerDay, 60.0);
      expect(e.deposit, 400.0);
    });

    test('missing price fields default to 0 and due_date may be null', () {
      final e = Equipment.fromJson({
        ...json,
        'status': 'available',
        'due_date': null,
      }..remove('price_per_day')..remove('deposit'));
      expect(e.pricePerDay, 0);
      expect(e.deposit, 0);
      expect(e.dueDate, isNull);
      expect(e.toJson()['due_date'], isNull);
    });

    test('an unknown status is treated as maintenance (never rentable)', () {
      final e = Equipment.fromJson({...json, 'status': 'something-new'});
      expect(e.status, EquipmentStatus.maintenance);
      expect(e.selectable, isFalse);
    });

    test('only available items are selectable', () {
      for (final status in EquipmentStatus.values) {
        final e = Equipment.fromJson({...json, 'status': status.name});
        expect(e.selectable, status == EquipmentStatus.available, reason: status.name);
      }
    });
  });

  group('Category JSON', () {
    test('round trip', () {
      final json = {'id': 2, 'name': 'เครื่องเสียง'};
      final c = Category.fromJson(json);
      expect(c.id, 2);
      expect(c.name, 'เครื่องเสียง');
      expect(c.toJson(), json);
    });

    test('accepts the backend value-array category form', () {
      final c = Category.fromJson({'id': 2, 'category_name': 'เครื่องเสียง'});
      expect(c.name, 'เครื่องเสียง');
    });
  });

  group('EquipmentRepository', () {
    test('accepts the backend raw array response', () async {
      final payload = [
        {
          'id': 3,
          'asset_code': 'WT-005',
          'name': 'วอล์กกี้ทอล์กกี้ Motorola',
          'category_id': 3,
          'category_name': 'วิทยุสื่อสาร',
          'image_url': null,
          'price_per_day': '60.00',
          'deposit': '400.00',
          'status': 'borrowed',
          'due_date': '2026-11-02',
        },
      ];

      final repo = ApiEquipmentRepository(ApiClient(
        baseUrl: 'http://test',
        client: MockClient((_) async => http.Response.bytes(
              utf8.encode(jsonEncode(payload)),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            )),
      ));

      final items = await repo.fetchEquipment();
      expect(items, hasLength(1));
      expect(items.first.categoryName, 'วิทยุสื่อสาร');
      expect(items.first.pricePerDay, 60.0);
      expect(items.first.deposit, 400.0);
    });
  });

  group('AppUser JSON', () {
    test('borrower round trip', () {
      final json = {
        'id': 7,
        'username': '6731500002',
        'full_name': 'มาลี รักเรียน',
        'role': 'borrower',
      };
      final u = AppUser.fromJson(json);
      expect(u.fullName, 'มาลี รักเรียน');
      expect(u.role, UserRole.borrower);
      expect(u.toJson(), json);
    });

    test('admin role is parsed and written back', () {
      final u = AppUser.fromJson({
        'id': 1,
        'username': 'admin',
        'full_name': 'ผู้ดูแลระบบ',
        'role': 'admin',
      });
      expect(u.role, UserRole.admin);
      expect(u.toJson()['role'], 'admin');
    });

    test('an unknown role falls back to borrower (least privilege)', () {
      final u = AppUser.fromJson({
        'id': 1,
        'username': 'x',
        'full_name': 'x',
        'role': 'superuser',
      });
      expect(u.role, UserRole.borrower);
    });
  });
}
