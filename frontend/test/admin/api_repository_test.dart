import 'dart:convert';

import 'package:frontend/core/api_client.dart';
import 'package:frontend/features/admin/repositories/api_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  late List<http.Request> sent;

  setUp(() {
    sent = [];
    ApiRepository.client = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((request) async {
        sent.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode([
              {
                'id': 42,
                'user_id': 7,
                'user_name': 'Test Renter',
                'item_count': 2,
                'purpose': 'Class project',
                'start_date': '2026-11-20',
                'end_date': '2026-11-22',
                'status': 'pending',
                'total_price': '150.00',
                'total_deposit': '400.00',
                'payment_status': 'pending',
                'slip_url': null,
                'fine_amount': '0.00',
                'fine_paid': 0,
              },
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response(
          jsonEncode({'message': 'Borrow request approved'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    )..token = 'admin-token';
  });

  tearDown(() {
    ApiRepository.client = null;
  });

  test('loads pending borrow requests through the admin endpoint', () async {
    final requests = await ApiRepository().getPendingBorrowRequests();

    expect(sent.single.method, 'GET');
    expect(sent.single.url.path, '/api/borrows');
    expect(sent.single.url.queryParameters['status'], 'pending');
    expect(sent.single.headers['authorization'], 'Bearer admin-token');
    expect(requests, hasLength(1));
    expect(requests.single.userName, 'Test Renter');
    expect(requests.single.itemCount, 2);
  });

  test(
    'approves a borrow request through the backend approval route',
    () async {
      await ApiRepository().reviewBorrowRequest(42, approve: true);

      expect(sent.single.method, 'PUT');
      expect(sent.single.url.path, '/api/borrows/42/approve');
      expect(sent.single.headers['authorization'], 'Bearer admin-token');
      expect(jsonDecode(sent.single.body), {'status': 'approved'});
    },
  );
}
