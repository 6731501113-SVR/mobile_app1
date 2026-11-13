import 'dart:convert';

import 'package:frontend/core/api_client.dart';
import 'package:frontend/features/borrow/borrow_models.dart';
import 'package:frontend/features/borrow/borrow_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('fetchMine parses the backend borrow request and nested equipment items', () async {
    final payload = [
      {
        'id': 42,
        'user_id': 7,
        'purpose': 'Class project',
        'start_date': '2026-11-20',
        'end_date': '2026-11-22',
        'total_price': '150.00',
        'total_deposit': '400.00',
        'status': 'approved',
        'payment_status': 'pending',
        'slip_url': null,
        'payment_due_at': '2026-11-14T08:00:00.000Z',
        'actual_return_date': null,
        'fine_amount': '0.00',
        'fine_paid': 0,
        'admin_note': null,
        'items': [
          {
            'id': 1,
            'request_id': 42,
            'equipment_id': 3,
            'equipment_name': 'Camera',
            'asset_code': 'CAM-01',
            'condition_after': null,
            'fine_amount': '0.00',
            'fine_paid': 0,
          },
          {
            'id': 2,
            'request_id': 42,
            'equipment_id': 4,
            'equipment_name': 'Tripod',
            'asset_code': 'TRI-01',
            'condition_after': null,
            'fine_amount': '0.00',
            'fine_paid': 0,
          },
        ],
      },
    ];
    final sent = <http.Request>[];
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((request) async {
        sent.add(request);
        return http.Response.bytes(
          utf8.encode(jsonEncode(payload)),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    )..token = 'header.${base64Url.encode(utf8.encode(jsonEncode({'id': 7})))}.signature';

    final requests = await ApiBorrowRepository(api).fetchMine();

    expect(sent.single.url.path, '/api/borrows/user/7');
    expect(requests, hasLength(1));
    final request = requests.single;
    expect(request.id, 42);
    expect(request.equipmentName, 'Camera, Tripod');
    expect(request.assetCode, 'CAM-01, TRI-01');
    expect(request.status, RequestStatus.approved);
    expect(request.awaitingPayment, isTrue);
    expect(request.pricePerDay, 50);
    expect(request.deposit, 400);
  });
}
