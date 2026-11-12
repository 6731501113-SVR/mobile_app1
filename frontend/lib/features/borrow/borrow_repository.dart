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

  List<BorrowRequest> _list(dynamic json) =>
      ((json as Map<String, dynamic>)['items'] as List)
          .map((e) => BorrowRequest.fromJson(e as Map<String, dynamic>))
          .toList();

  @override
  Future<List<BorrowRequest>> create({
    required List<int> equipmentIds,
    required String purpose,
    required DateTime start,
    required DateTime end,
  }) async =>
      _list(await _api.post('/api/borrow-requests', body: {
        'equipment_ids': equipmentIds,
        'purpose': purpose,
        'start_date': isoDate(start),
        'end_date': isoDate(end),
      }));

  @override
  Future<List<BorrowRequest>> fetchMine({String tab = 'all'}) async =>
      _list(await _api.get('/api/borrow-requests/mine', query: {'tab': tab}));

  @override
  Future<List<DateRange>> fetchBookedRanges(int equipmentId) async {
    final j = await _api.get('/api/equipment/$equipmentId/booked-dates')
        as Map<String, dynamic>;
    return (j['ranges'] as List)
        .map((r) => DateRange(
              parseDate((r as Map)['start_date'] as String),
              parseDate(r['end_date'] as String),
            ))
        .toList();
  }

  @override
  Future<BorrowRequest> fetchOne(int id) async => BorrowRequest.fromJson(
      await _api.get('/api/borrow-requests/$id') as Map<String, dynamic>);

  @override
  Future<BorrowRequest> cancel(int id) async => BorrowRequest.fromJson(
      await _api.post('/api/borrow-requests/$id/cancel') as Map<String, dynamic>);
}
