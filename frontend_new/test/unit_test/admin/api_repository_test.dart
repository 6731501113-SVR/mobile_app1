import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/features/admin/data/api_repository.dart';
import 'package:frontend/features/admin/screens/admin_pending_borrow_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _requestRow(
  int id,
  String status,
  String paymentStatus,
) => {
  'id': id,
  'user_id': 7,
  'user_name': 'Test Renter',
  'item_count': 2,
  'purpose': 'Class project',
  'start_date': '2026-11-20',
  'end_date': '2026-11-22',
  'status': status,
  'total_price': '150.00',
  'total_deposit': '400.00',
  'payment_status': paymentStatus,
  'slip_url': null,
  'fine_amount': '0.00',
  'fine_paid': 0,
  'items': [
    {'equipment_id': 31, 'equipment_name': 'Camera', 'asset_code': 'CAM-31'},
    {'equipment_id': 32, 'equipment_name': 'Tripod', 'asset_code': 'TRI-32'},
  ],
};

void main() {
  late List<http.Request> sent;

  setUp(() {
    sent = [];
    ApiRepository.client = ApiClient(
      baseUrl: 'http://test',
      client: MockClient((request) async {
        sent.add(request);
        if (request.method == 'GET') {
          if (request.url.path == '/api/borrows/42') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'items': [
                    {
                      'equipment_id': 31,
                      'equipment_name': 'Camera',
                      'asset_code': 'CAM-31',
                    },
                  ],
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          final rows = request.url.queryParameters['status'] == 'pending'
              ? [_requestRow(42, 'pending', 'pending')]
              : [
                  _requestRow(42, 'approved', 'paid'),
                  _requestRow(43, 'approved', 'pending'),
                  _requestRow(44, 'borrowed', 'paid'),
                ];
          return http.Response(
            jsonEncode(rows),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.endsWith('/return')) {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'borrow_id': 42,
                'late_days': 1,
                'late_fine': 30,
                'total_damage_fine': 100,
                'fine_amount': 130,
              },
            }),
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
    expect(
      requests.single.items
          .map((item) => '${item.equipmentName} (${item.assetCode})')
          .toList(),
      ['Camera (CAM-31)', 'Tripod (TRI-32)'],
    );
  });

  testWidgets(
    'pending request loads equipment names from its detail endpoint',
    (tester) async {
      final row = _requestRow(42, 'pending', 'pending')..remove('items');
      ApiRepository.client = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          if (request.url.path == '/api/borrows/42') {
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'items': [
                    {
                      'equipment_id': 31,
                      'equipment_name': 'Projector',
                      'asset_code': 'PROJ-31',
                    },
                  ],
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode([row]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      )..token = 'admin-token';

      await tester.pumpWidget(
        const MaterialApp(home: AdminPendingBorrowScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('• Projector (PROJ-31)'), findsOneWidget);
    },
  );

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

  test(
    'delivery list contains only paid approvals and borrowed requests',
    () async {
      final requests = await ApiRepository().getDeliveryRequests();

      expect(sent.single.method, 'GET');
      expect(sent.single.url.path, '/api/borrows');
      expect(sent.single.headers['authorization'], 'Bearer admin-token');
      expect(requests.map((request) => request.id), [42, 44]);
    },
  );

  test('handover uses the backend route', () async {
    await ApiRepository().processHandover(42);

    expect(sent.single.method, 'PUT');
    expect(sent.single.url.path, '/api/borrows/42/handover');
    expect(sent.single.headers['authorization'], 'Bearer admin-token');
  });

  test('return sends per-item condition and damage fine to backend', () async {
    final repository = ApiRepository();
    final items = await repository.getBorrowRequestItems(42);
    final result = await repository.processReturn(42, [
      {
        'equipment_id': items.single.equipmentId,
        'condition_after': 'damaged',
        'damage_fine': 100,
      },
    ]);

    expect(items.single.equipmentName, 'Camera');
    expect(sent.last.method, 'PUT');
    expect(sent.last.url.path, '/api/borrows/42/return');
    expect(jsonDecode(sent.last.body), {
      'items': [
        {'equipment_id': 31, 'condition_after': 'damaged', 'damage_fine': 100},
      ],
    });
    expect(result['late_fine'], 30);
  });
}
