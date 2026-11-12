import '../../core/api_client.dart';
import '../../core/models.dart';

abstract class EquipmentRepository {
  Future<List<Category>> fetchCategories();
  Future<List<Equipment>> fetchEquipment();
}

class ApiEquipmentRepository implements EquipmentRepository {
  ApiEquipmentRepository(this._api);
  final ApiClient _api;

  List<T> _items<T>(dynamic json, T Function(Map<String, dynamic>) f) {
    final raw = json is List
        ? json
        : (json is Map ? (json['data'] ?? json['items'] ?? const <dynamic>[]) : const <dynamic>[]);
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => f(Map<String, dynamic>.from(e)))
        .toList();
  }

  @override
  Future<List<Category>> fetchCategories() async =>
      _items(await _api.get('/api/categories'), Category.fromJson);

  @override
  Future<List<Equipment>> fetchEquipment() async =>
      _items(await _api.get('/api/equipments'), Equipment.fromJson);
}
