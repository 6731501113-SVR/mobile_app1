import '../../core/api_client.dart';
import '../../core/models.dart';

abstract class EquipmentRepository {
  Future<List<Category>> fetchCategories();
  Future<List<Equipment>> fetchEquipment();
}

class ApiEquipmentRepository implements EquipmentRepository {
  ApiEquipmentRepository(this._api);
  final ApiClient _api;

  List<T> _items<T>(dynamic json, T Function(Map<String, dynamic>) f) =>
      ((json as Map<String, dynamic>)['items'] as List)
          .map((e) => f(e as Map<String, dynamic>))
          .toList();

  @override
  Future<List<Category>> fetchCategories() async =>
      _items(await _api.get('/api/categories'), Category.fromJson);

  @override
  Future<List<Equipment>> fetchEquipment() async =>
      _items(await _api.get('/api/equipment'), Equipment.fromJson);
}
