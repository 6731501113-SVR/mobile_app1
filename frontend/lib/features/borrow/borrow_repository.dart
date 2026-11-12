import 'dart:convert';

import '../../core/api_client.dart';
import '../../core/dates.dart';
import 'borrow_models.dart';

abstract class BorrowRepository {
  /// One request row is created per equipment id (all-or-nothing).
  Future<List<BorrowRequest>> create({
    required List<int> equipmentIds,
    required String purpose,
    required DateTime start,
    required DateTime end,
  });

  /// tab: all | pending | borrowing | history
  Future<List<BorrowRequest>> fetchMine({String tab = 'all'});

  /// Dates already booked for one item (greyed out in the calendar).
  Future<List<DateRange>> fetchBookedRanges(int equipmentId);

  Future<BorrowRequest> fetchOne(int id);
  Future<BorrowRequest> cancel(int id);
}

class ApiBorrowRepository implements BorrowRepository {
  ApiBorrowRepository(this._api);
  final ApiClient _api;

  int? _currentUserId() {
    final token = _api.token;
    if (token == null || token.isEmpty) return null;

    try {
      final parts = token.split('.');
      if (parts.length < 2) return null;
      final payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      final padded = payload.padRight((payload.length + 3) & ~3, '=');
      final json = _decodeJson(padded);
      return int.tryParse('${json['id']}');
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _decodeJson(String base64Payload) {
    final decoded = utf8.decode(base64Url.decode(base64Payload));
    return Map<String, dynamic>.from(jsonDecode(decoded) as Map);
  }

  List<BorrowRequest> _list(dynamic json) {
    final raw = json is List
        ? json
        : (json is Map ? (json['data'] ?? json['items'] ?? const <dynamic>[]) : const <dynamic>[]);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => BorrowRequest.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<BorrowRequest>> create({
    required List<int> equipmentIds,
    required String purpose,
    required DateTime start,
    required DateTime end,
  }) async {
    await _api.post('/api/borrows', body: {
      'equipment_ids': equipmentIds,
      'purpose': purpose,
      'start_date': isoDate(start),
      'end_date': isoDate(end),
    });
    return const <BorrowRequest>[];
  }

  @override
  Future<List<BorrowRequest>> fetchMine({String tab = 'all'}) async {
    final userId = _currentUserId();
    if (userId == null) {
      throw const ApiException('กรุณาเข้าสู่ระบบก่อน', code: 'UNAUTHORIZED');
    }
    return _list(await _api.get('/api/borrows/user/$userId'));
  }

  @override
  Future<List<DateRange>> fetchBookedRanges(int equipmentId) async {
    final j = await _api.get('/api/borrows/equipment/$equipmentId/booked-dates')
        as Map<String, dynamic>;
    final ranges = (j['booked_dates'] ?? const <dynamic>[]) as List;
    return ranges.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      return DateRange(
        parseDate(map['start_date'] as String),
        parseDate(map['end_date'] as String),
      );
    }).toList();
  }

  @override
  Future<BorrowRequest> fetchOne(int id) async {
    final j = await _api.get('/api/borrows/$id') as Map<String, dynamic>;
    final row = (j['data'] is Map) ? j['data'] as Map<String, dynamic> : j;
    return BorrowRequest.fromJson(row);
  }

  @override
  Future<BorrowRequest> cancel(int id) async {
    final j = await _api.put('/api/borrows/$id/cancel') as Map<String, dynamic>;
    final row = (j['data'] is Map) ? j['data'] as Map<String, dynamic> : j;
    return BorrowRequest.fromJson(row);
  }
}
