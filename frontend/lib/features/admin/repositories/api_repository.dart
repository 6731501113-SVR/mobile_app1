import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../../../core/api_client.dart';
import '../models/equipment.dart';
import '../models/borrow_request.dart';

class ApiRepository {
  /// Same backend as the rest of the app (override with --dart-define=API_BASE_URL).
  static const String serverUrl = kApiBaseUrl;
  static const String baseUrl = '$kApiBaseUrl/api';

  /// Set once in main.dart so admin calls carry the logged-in admin's token.
  static ApiClient? client;

  static Map<String, String> _headers({bool json = false}) => {
    if (json) 'Content-Type': 'application/json',
    if (client?.token != null) 'Authorization': 'Bearer ${client!.token}',
  };

  ApiClient get _authenticatedClient {
    final api = client;
    if (api == null) {
      throw StateError('ApiRepository.client has not been configured');
    }
    return api;
  }

  // --- Equipment APIs ---
  Future<List<Equipment>> getEquipmentList() async {
    final response = await http.get(
      Uri.parse('$baseUrl/equipments'),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      Iterable list = json.decode(response.body);
      List<Equipment> equipments = list
          .map((model) => Equipment.fromJson(model))
          .toList();

      // จัดเรียง: สินค้าที่มีสต็อกเหลือ (stock > 0) ขึ้นมาแสดงอยู่ด้านบนสุด
      equipments.sort((a, b) {
        if (a.stock > 0 && b.stock == 0) return -1;
        if (a.stock == 0 && b.stock > 0) return 1;
        return b.stock.compareTo(a.stock);
      });

      return equipments;
    } else {
      throw Exception('Failed to load equipment');
    }
  }

  // --- Category APIs ---
  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await http.get(
      Uri.parse('$baseUrl/categories'),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      final list = decoded is Map
          ? (decoded['data'] ?? decoded['items'] ?? decoded['value']) as List
          : decoded as List;
      return list.map((category) {
        final item = Map<String, dynamic>.from(category as Map);
        final name = item['name'] ?? item['category_name'];
        if (name is! String || name.isEmpty) {
          throw const FormatException('Category response is missing its name');
        }
        return {...item, 'name': name};
      }).toList();
    }
    throw Exception('Failed to load categories');
  }

  // เพิ่มหมวดหมู่ (Category)
  Future<bool> saveCategory(String categoryName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: _headers(json: true),
      body: json.encode({'category_name': categoryName}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // รองรับการอัปโหลดรูปภาพด้วย MultipartRequest
  Future<bool> saveEquipmentWithImage(
    Equipment equipment, {
    XFile? imageFile,
    bool isUpdate = false,
  }) async {
    final uri = isUpdate
        ? Uri.parse('$baseUrl/equipments/${equipment.id}')
        : Uri.parse('$baseUrl/equipments');

    var request = http.MultipartRequest(isUpdate ? 'PUT' : 'POST', uri);
    request.headers.addAll(_headers());

    request.fields['asset_code'] = equipment.assetCode;
    request.fields['name'] = equipment.name;
    request.fields['category_id'] = equipment.categoryId.toString();
    request.fields['status'] = equipment.status;
    request.fields['price_per_day'] = equipment.pricePerDay.toString();
    request.fields['deposit'] = equipment.deposit.toString();
    request.fields['stock'] = equipment.stock.toString();

    if (imageFile != null) {
      final contentType = _imageContentType(imageFile);
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        await imageFile.readAsBytes(),
        filename: imageFile.name,
        contentType: contentType,
      ));
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) return true;

    String message = 'Equipment save failed (${response.statusCode})';
    if (response.body.isNotEmpty) {
      try {
        final body = json.decode(response.body);
        if (body is Map && body['message'] is String) {
          message = body['message'] as String;
        }
      } on FormatException {
        // Keep the HTTP status message when the server response is not JSON.
      }
    }
    throw Exception(message);
  }

  MediaType _imageContentType(XFile imageFile) {
    final mimeType = imageFile.mimeType;
    if (mimeType != null) {
      switch (mimeType.toLowerCase()) {
        case 'image/jpeg':
          return MediaType('image', 'jpeg');
        case 'image/png':
          return MediaType('image', 'png');
        case 'image/gif':
          return MediaType('image', 'gif');
        case 'image/webp':
          return MediaType('image', 'webp');
      }
    }

    final extension = imageFile.name.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return MediaType('image', 'jpeg');
      case 'png':
        return MediaType('image', 'png');
      case 'gif':
        return MediaType('image', 'gif');
      case 'webp':
        return MediaType('image', 'webp');
      default:
        throw FormatException('Unsupported image type: ${imageFile.name}');
    }
  }

  // --- Slip & Borrow Request APIs ---
  Future<List<BorrowRequest>> getPendingBorrowRequests() async {
    final decoded = await _authenticatedClient.get(
      '/api/borrows',
      query: {'status': 'pending'},
    );
    if (decoded is! List) {
      throw const FormatException('Invalid pending borrow requests response');
    }
    return decoded.map((row) {
      if (row is! Map) {
        throw const FormatException('Invalid pending borrow request');
      }
      return BorrowRequest.fromJson(Map<String, dynamic>.from(row));
    }).toList();
  }

  Future<void> reviewBorrowRequest(
    int requestId, {
    required bool approve,
    String? adminNote,
  }) async {
    await _authenticatedClient.put(
      '/api/borrows/$requestId/approve',
      body: {
        'status': approve ? 'approved' : 'rejected',
        if (adminNote != null && adminNote.trim().isNotEmpty)
          'admin_note': adminNote.trim(),
      },
    );
  }

  Future<List<BorrowRequest>> getPendingSlips() async {
    final response = await http.get(
      Uri.parse('$baseUrl/borrows').replace(queryParameters: {'status': 'approved'}),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      final decoded = json.decode(response.body);
      if (decoded is! List) {
        throw const FormatException('Invalid pending slips response');
      }
      return decoded
          .map((model) => BorrowRequest.fromJson(Map<String, dynamic>.from(model as Map)))
          .where((request) =>
              request.paymentStatus == 'pending' &&
              request.slipUrl != null &&
              request.slipUrl!.isNotEmpty)
          .toList();
    }
    throw Exception(_responseMessage(response, 'Failed to load pending slips'));
  }

  Future<bool> verifySlip(int requestId, bool approve, String adminNote) async {
    final response = await http.put(
      Uri.parse('$baseUrl/borrows/$requestId/verify-payment'),
      headers: _headers(json: true),
      body: json.encode({
        'payment_status': approve ? 'paid' : 'rejected',
        'admin_note': adminNote,
      }),
    );
    return response.statusCode == 200;
  }

  String _responseMessage(http.Response response, String fallback) {
    if (response.body.isEmpty) return '$fallback (${response.statusCode})';
    try {
      final body = json.decode(response.body);
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
    } on FormatException {
      // Use the status-based message for non-JSON responses.
    }
    return '$fallback (${response.statusCode})';
  }

  // --- Delivery & Return APIs ---
  Future<bool> processReturn(
    int requestId,
    double fineAmount,
    String conditionAfter,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/borrow/return/$requestId'),
      headers: _headers(json: true),
      body: json.encode({
        'fine_amount': fineAmount,
        'condition_after': conditionAfter,
      }),
    );
    return response.statusCode == 200;
  }
}
