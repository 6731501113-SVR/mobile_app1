import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/api_client.dart';
import 'package:frontend/features/borrow/borrow_models.dart';
import 'package:frontend/features/borrow/borrow_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'uploadSlip uses the authenticated backend multipart endpoint',
    () async {
      http.Request? sent;
      final api = ApiClient(
        baseUrl: 'http://test',
        client: MockClient((request) async {
          sent = request;
          return http.Response(
            jsonEncode({'success': true, 'slip_url': '/uploads/slip-test.png'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      )..token = 'user-token';

      await ApiBorrowRepository(api).uploadSlip(
        requestId: 42,
        fileName: 'slip.png',
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      );

      final request = sent!;
      expect(request.method, 'PUT');
      expect(request.url.path, '/api/borrows/42/slip');
      expect(request.headers['authorization'], 'Bearer user-token');
      expect(
        request.headers['content-type'],
        startsWith('multipart/form-data;'),
      );
      expect(request.body, contains('name="slip"'));
      expect(request.body, contains('filename="slip.png"'));
      expect(request.body, contains('image/png'));
    },
  );

  test('uploadSlip exposes backend upload errors', () async {
    final api = ApiClient(
      baseUrl: 'http://test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'success': false,
            'message': 'Only image files are allowed',
          }),
          400,
          headers: {'content-type': 'application/json'},
        ),
      ),
    )..token = 'user-token';

    await expectLater(
      ApiBorrowRepository(api).uploadSlip(
        requestId: 42,
        fileName: 'slip.png',
        bytes: Uint8List.fromList([1, 2, 3]),
        mimeType: 'image/png',
      ),
      throwsA(
        isA<ApiException>()
            .having((error) => error.code, 'code', 'BAD_FILE')
            .having(
              (error) => error.message,
              'message',
              'กรุณาแนบรูปภาพ (jpg, png, gif, webp)',
            ),
      ),
    );
  });

  test('approved request without a payment deadline still offers payment', () {
    final request = BorrowRequest(
      id: 42,
      equipmentId: 3,
      equipmentName: 'Camera',
      assetCode: 'CAM-01',
      purpose: 'Class project',
      startDate: DateTime(2026, 11, 20),
      endDate: DateTime(2026, 11, 22),
      status: RequestStatus.approved,
      lateDays: 0,
      fineAmount: 0,
      finePaid: false,
      estimatedFine: 0,
      finePerDay: 30,
      paymentStatus: 'unpaid',
    );

    expect(request.awaitingPayment, isTrue);
  });

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
