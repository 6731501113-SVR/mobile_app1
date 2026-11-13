import 'package:flutter/foundation.dart' hide Category;

import '../../core/api_client.dart';
import '../../core/models.dart';
import 'equipment_repository.dart';

/// State for the home screen: loading, search, category filter and the
/// multi-select basket. No widgets here, so it is unit-testable.
class EquipmentListController extends ChangeNotifier {
  EquipmentListController(this._repo);

  final EquipmentRepository _repo;

  List<Equipment> _all = const [];
  List<Category> _categories = const [];
  bool _loading = true;
  String? _error;
  String _query = '';
  int? _categoryId; // null = all categories

  /// Selected equipment ids. Kept across search / filter changes so the user
  /// can pick items from several categories.
  final Set<int> _selected = {};
  bool _disposed = false;

  bool get loading => _loading;
  String? get error => _error;
  List<Category> get categories => _categories;
  int? get categoryId => _categoryId;
  String get query => _query;
  int get selectedCount => _selected.length;
  bool isSelected(int id) => _selected.contains(id);

  /// Equipment after applying category + search.
  List<Equipment> get visible {
    final q = _query.trim().toLowerCase();
    return _all.where((e) {
      if (_categoryId != null && e.categoryId != _categoryId) return false;
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) || e.assetCode.toLowerCase().contains(q);
    }).toList();
  }

  List<Equipment> get selectedItems =>
      _all.where((e) => _selected.contains(e.id)).toList();

  /// [showSpinner] false = pull-to-refresh / background refresh: a failure then
  /// keeps the list on screen instead of replacing it with an error.
  Future<void> load({bool showSpinner = true}) async {
    if (showSpinner) {
      _loading = true;
      _error = null;
      _notify();
    }
    try {
      final equipment = await _repo.fetchEquipment();
      final categories = await _repo.fetchCategories();
      final orderedEquipment = equipment.asMap().entries.toList()
        ..sort((a, b) {
          final availability = (b.value.selectable ? 1 : 0)
              .compareTo(a.value.selectable ? 1 : 0);
          return availability != 0 ? availability : a.key.compareTo(b.key);
        });
      _all = orderedEquipment.map((entry) => entry.value).toList();
      _categories = categories;
      // Drop selections that are no longer available after a refresh.
      _selected.retainAll(_all.where((e) => e.selectable).map((e) => e.id).toSet());
      _error = null;
    } on ApiException catch (e) {
      if (showSpinner || _all.isEmpty) _error = e.message;
    } catch (_) {
      if (showSpinner || _all.isEmpty) _error = 'โหลดรายการอุปกรณ์ไม่สำเร็จ';
    } finally {
      _loading = false;
      _notify();
    }
  }

  void setQuery(String value) {
    if (value == _query) return;
    _query = value;
    _notify();
  }

  void selectCategory(int? id) {
    if (id == _categoryId) return;
    _categoryId = id;
    _notify();
  }

  /// Toggles one item. Items that are not available can't be selected.
  void toggle(int id) {
    final index = _all.indexWhere((e) => e.id == id);
    if (index < 0 || !_all[index].selectable) return;
    if (!_selected.remove(id)) _selected.add(id);
    _notify();
  }

  void clearSelection() {
    if (_selected.isEmpty) return;
    _selected.clear();
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
