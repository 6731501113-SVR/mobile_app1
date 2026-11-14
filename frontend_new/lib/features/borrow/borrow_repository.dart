import 'dart:convert';
import 'dart:typed_data';

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
  Future<void> uploadSlip({
    required int requestId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  });
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

  double _number(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw FormatException('Invalid numeric borrow value: $value');
  }

  int _integer(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse('$value');
    if (parsed != null) return parsed;
    throw FormatException('Invalid integer borrow value: $value');
  }

  bool _boolean(dynamic value) =>
      value == true || value == 1 || value == '1' || value == 'true';

  BorrowRequest _fromBackendRow(Map<String, dynamic> row) {
    final rawItems = row['items'];
    if (rawItems is! List || rawItems.isEmpty) {
      throw const FormatException('Borrow request has no equipment items');
    }

    final items = rawItems.map((item) => Map<String, dynamic>.from(item as Map)).toList();
    final startDate = parseDate((row['start_date'] as String).substring(0, 10));
    final endDate = parseDate((row['end_date'] as String).substring(0, 10));
    final returnDate = row['actual_return_date'] == null
        ? null
        : parseDate((row['actual_return_date'] as String).substring(0, 10));
    final referenceDate = returnDate ?? DateTime.now();
    final today = DateTime(referenceDate.year, referenceDate.month, referenceDate.day);
    final lateDays = today.difference(endDate).inDays.clamp(0, 1000000);
    final status = row['status'] as String;

    final displayStatus = switch (status) {
      'approved' => RequestStatus.approved,
      'borrowed' when lateDays > 0 => RequestStatus.overdue,
      'borrowed' => RequestStatus.borrowing,
      _ => RequestStatus.values.firstWhere(
          (candidate) => candidate.name == status,
          orElse: () => throw FormatException('Unknown borrow status: $status'),
        ),
    };

    final names = items.map((item) => item['equipment_name'] as String).toList();
    final assetCodes = items.map((item) => item['asset_code'] as String).toList();
    final rentalDays = endDate.difference(startDate).inDays + 1;
    final totalPrice = _number(row['total_price']);
    final totalDeposit = _number(row['total_deposit']);
    final slipUrl = row['slip_url'] as String?;
    final paymentStatus = switch (row['payment_status']) {
      'paid' => 'paid',
      'rejected' => 'rejected',
      _ when slipUrl != null && slipUrl.isNotEmpty => 'pending_review',
      _ => 'unpaid',
    };

    return BorrowRequest(
      id: _integer(row['id']),
      equipmentId: _integer(items.first['equipment_id']),
      equipmentName: names.join(', '),
      assetCode: assetCodes.join(', '),
      purpose: (row['purpose'] ?? '') as String,
      startDate: startDate,
      endDate: endDate,
      actualReturnDate: returnDate,
      status: displayStatus,
      lateDays: lateDays,
      daysLeft: endDate.difference(today).inDays.clamp(0, 1000000),
      fineAmount: _number(row['fine_amount']),
      finePaid: _boolean(row['fine_paid']),
      estimatedFine: lateDays * 30.0,
      finePerDay: 30,
      conditionAfter: items
          .map((item) => item['condition_after'] as String?)
          .firstWhere((condition) => condition != null, orElse: () => null),
      adminNote: row['admin_note'] as String?,
      pricePerDay: rentalDays > 0 ? totalPrice / rentalDays : 0,
      deposit: totalDeposit,
      paymentStatus: paymentStatus,
      paymentDueAt: row['payment_due_at'] == null
          ? null
          : DateTime.parse(row['payment_due_at'] as String).toLocal(),
      paymentNote: row['admin_note'] as String?,
    );
  }

  List<BorrowRequest> _list(dynamic json) {
    final raw = json is List
        ? json
        : (json is Map ? (json['data'] ?? json['items'] ?? const <dynamic>[]) : null);
    if (raw is! List) {
      throw const FormatException('Invalid borrow list response');
    }
    return raw.map((entry) {
      if (entry is! Map) {
        throw const FormatException('Invalid borrow request entry');
      }
      return _fromBackendRow(Map<String, dynamic>.from(entry));
    }).toList();
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
    final all = _list(await _api.get('/api/borrows/user/$userId'));
    return all.where((r) => _inTab(r.status, tab)).toList();
  }

  static bool _inTab(RequestStatus s, String tab) => switch (tab) {
        'pending' => s == RequestStatus.pending || s == RequestStatus.approved,
        'borrowing' => s == RequestStatus.borrowing || s == RequestStatus.overdue,
        'history' => s == RequestStatus.returned ||
            s == RequestStatus.rejected ||
            s == RequestStatus.cancelled,
        _ => true,
      };

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
    return _fromBackendRow(row);
  }

  @override
  Future<BorrowRequest> cancel(int id) async {
    await _api.put('/api/borrows/$id/cancel');
    return fetchOne(id);
  }

  @override
  Future<void> uploadSlip({
    required int requestId,
    required String fileName,
    required Uint8List bytes,
    String? mimeType,
  }) async {
    final contentType = _slipContentType(fileName, mimeType);
    await _api.putMultipart(
      '/api/borrows/$requestId/slip',
      fieldName: 'slip',
      fileName: fileName,
      bytes: bytes,
      contentType: contentType,
    );
  }

  String _slipContentType(String fileName, String? mimeType) {
    if (mimeType == 'image/jpeg' || mimeType == 'image/png') return mimeType!;
    return switch (fileName.toLowerCase().split('.').last) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => throw FormatException('Unsupported payment slip image: $fileName'),
    };
  }
}
