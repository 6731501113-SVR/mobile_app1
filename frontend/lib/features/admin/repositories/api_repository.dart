import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/api_client.dart';
import '../models/equipment.dart';
import '../models/borrow_request.dart';

class ApiRepository {
  /// Same backend as the rest of the app (override with --dart-define=API_BASE_URL).
  static const String baseUrl = '$kApiBaseUrl/api';

  /// Set once in main.dart so admin calls carry the logged-in admin's token.
  static ApiClient? client;

  static Map<String, String> _headers({bool json = false}) => {
    if (json) 'Content-Type': 'application/json',
    if (client?.token != null) 'Authorization': 'Bearer ${client!.token}',
  };

  // --- Equipment APIs ---
  Future<List<Equipment>> getEquipmentList() async {
    final response = await http.get(
      Uri.parse('$baseUrl/equipment'),
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
      // Editor 1's client reads a plain list or {items: [...]}; accept both.
      final list = decoded is Map ? decoded['items'] as List : decoded as List;
      return list.cast<Map<String, dynamic>>();
    }
    throw Exception('Failed to load categories');
  }

  // เพิ่มหมวดหมู่ (Category)
  Future<bool> saveCategory(String categoryName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/categories'),
      headers: _headers(json: true),
      body: json.encode({'name': categoryName}),
    );
    return response.statusCode == 200 || response.statusCode == 201;
  }

  // รองรับการอัปโหลดรูปภาพด้วย MultipartRequest
  Future<bool> saveEquipmentWithImage(
    Equipment equipment, {
    File? imageFile,
    bool isUpdate = false,
  }) async {
    final uri = isUpdate
        ? Uri.parse('$baseUrl/equipment/${equipment.id}')
        : Uri.parse('$baseUrl/equipment');

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
      request.files.add(
        await http.MultipartFile.fromPath('image', imageFile.path),
      );
    }

    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);

    return response.statusCode == 200 || response.statusCode == 201;
  }

  // --- Slip & Borrow Request APIs ---
  Future<List<BorrowRequest>> getPendingSlips() async {
    final response = await http.get(
      Uri.parse('$baseUrl/borrow/pending-slips'),
      headers: _headers(),
    );
    if (response.statusCode == 200) {
      Iterable list = json.decode(response.body);
      return list.map((model) => BorrowRequest.fromJson(model)).toList();
    } else {
      throw Exception('Failed to load pending slips');
    }
  }

  Future<bool> verifySlip(int requestId, bool approve, String adminNote) async {
    final response = await http.post(
      Uri.parse('$baseUrl/borrow/verify-slip/$requestId'),
      headers: _headers(json: true),
      body: json.encode({
        'status': approve ? 'approved' : 'rejected',
        'payment_status': approve ? 'paid' : 'rejected',
        'admin_note': adminNote,
      }),
    );
    return response.statusCode == 200;
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
