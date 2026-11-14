import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api_client.dart';
import 'admin_borrow_request.dart';
import 'admin_equipment.dart';

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

      // The backend keeps one row per physical item (no stock column), so
      // sort by availability instead: available items first.
      int rank(String status) => status == 'available' ? 0 : 1;
      equipments.sort((a, b) => rank(a.status).compareTo(rank(b.status)));

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
          message = translateBackendMessage(body['message'] as String).message;
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
    return _parseBorrowRequests(decoded, 'Invalid pending borrow requests response');
  }

  Future<List<BorrowRequest>> getDeliveryRequests() async {
    final decoded = await _authenticatedClient.get('/api/borrows');
    return _parseBorrowRequests(decoded, 'Invalid borrow requests response')
        .where(
          (request) =>
              (request.status == 'approved' && request.paymentStatus == 'paid') ||
              request.status == 'borrowed',
        )
        .toList();
  }

  List<BorrowRequest> _parseBorrowRequests(dynamic decoded, String errorMessage) {
    if (decoded is! List) {
      throw FormatException(errorMessage);
    }
    return decoded.map((row) {
      if (row is! Map) {
        throw const FormatException('Invalid borrow request');
      }
      return BorrowRequest.fromJson(Map<String, dynamic>.from(row));
    }).toList();
  }

  Future<void> processHandover(int requestId) async {
    await _authenticatedClient.put('/api/borrows/$requestId/handover');
  }

  Future<List<BorrowRequestItem>> getBorrowRequestItems(int requestId) async {
    final decoded = await _authenticatedClient.get('/api/borrows/$requestId');
    if (decoded is! Map || decoded['data'] is! Map) {
      throw const FormatException('Invalid borrow request details response');
    }
    final items = (decoded['data'] as Map)['items'];
    if (items is! List) {
      throw const FormatException('Borrow request details are missing items');
    }
    return items.map((item) {
      if (item is! Map) {
        throw const FormatException('Invalid borrow request item');
      }
      return BorrowRequestItem.fromJson(Map<String, dynamic>.from(item));
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
        return translateBackendMessage(body['message'] as String).message;
      }
    } on FormatException {
      // Use the status-based message for non-JSON responses.
    }
    return '$fallback (${response.statusCode})';
  }

  // --- Delivery & Return APIs ---
  Future<Map<String, dynamic>> processReturn(
    int requestId,
    List<Map<String, dynamic>> items,
  ) async {
    final response = await _authenticatedClient.put(
      '/api/borrows/$requestId/return',
      body: {'items': items},
    );
    if (response is! Map || response['data'] is! Map) {
      throw const FormatException('Invalid return response');
    }
    return Map<String, dynamic>.from(response['data'] as Map);
  }
}
