import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/features/borrow/borrow_models.dart';
import 'package:frontend/features/borrow/borrow_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _row(
  int id,
  String status, {
  String start = '2026-11-20',
  String end = '2099-12-31',
}) =>
    {
      'id': id,
      'user_id': 7,
      'purpose': 'Class project',
      'start_date': start,
      'end_date': end,
      'total_price': '100.00',
      'total_deposit': '200.00',
      'status': status,
      'payment_status': 'pending',
      'slip_url': null,
      'payment_due_at': null,
      'actual_return_date': null,
      'fine_amount': '0.00',
      'fine_paid': 0,
      'admin_note': null,
      'items': [
        {
          'id': id,
          'request_id': id,
          'equipment_id': 1,
          'equipment_name': 'Camera',
          'asset_code': 'CAM-$id',
          'condition_after': null,
          'fine_amount': '0.00',
          'fine_paid': 0,
        },
      ],
    };

ApiBorrowRepository _repo(List<Map<String, dynamic>> rows) {
  final api = ApiClient(
    baseUrl: 'http://test',
    client: MockClient(
      (_) async => http.Response.bytes(
        utf8.encode(jsonEncode(rows)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      ),
    ),
  )..token = 'header.${base64Url.encode(utf8.encode(jsonEncode({'id': 7})))}.signature';
  return ApiBorrowRepository(api);
}

void main() {
  group('fetchMine tabs', () {
    final repo = _repo([
      _row(1, 'pending'),
      _row(2, 'approved'),
      _row(3, 'borrowed'),
      _row(4, 'borrowed', start: '2020-01-01', end: '2020-01-02'), // overdue
      _row(5, 'returned'),
      _row(6, 'cancelled'),
      _row(7, 'rejected'),
    ]);

    Future<List<int>> ids(String tab) async =>
        (await repo.fetchMine(tab: tab)).map((r) => r.id).toList();

    test('all shows everything', () async {
      expect(await ids('all'), [1, 2, 3, 4, 5, 6, 7]);
    });

    test('pending = waiting for approval or for payment', () async {
      expect(await ids('pending'), [1, 2]);
    });

    test('borrowing = on loan, including overdue', () async {
      expect(await ids('borrowing'), [3, 4]);
    });

    test('history = returned, rejected and cancelled', () async {
      expect(await ids('history'), [5, 6, 7]);
    });

    test('a borrowed request past its end date is shown as overdue', () async {
      final all = await repo.fetchMine();
      expect(all.firstWhere((r) => r.id == 4).status, RequestStatus.overdue);
      expect(all.firstWhere((r) => r.id == 3).status, RequestStatus.borrowing);
    });
  });
}
