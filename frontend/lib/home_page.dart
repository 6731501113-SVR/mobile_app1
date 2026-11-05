import 'package:flutter/material.dart';

import 'models.dart';
import 'repositories.dart';
import 'screens/booking_screen.dart';
import 'screens/my_loans_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.user,
    required this.repo,
    required this.onLogout,
  });

  final AppUser user;
  final EquipmentRepository repo;
  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  final _search = TextEditingController();
  int? _categoryId; // null = all

  /// Selected equipment ids. Kept across search/filter changes so the user
  /// can pick items from several categories.
  final Set<int> _selected = {};

  List<Equipment> _all = const [];
  List<Category> _categories = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool showSpinner = true}) async {
    if (showSpinner) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final equipment = await widget.repo.fetchEquipment();
      final categories = await widget.repo.fetchCategories();
      if (!mounted) return;
      setState(() {
        _all = equipment;
        _categories = categories;
        // Drop selections that are no longer available after a refresh.
        _selected.retainAll(
          equipment.where((e) => e.selectable).map((e) => e.id).toSet(),
        );
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'โหลดรายการอุปกรณ์ไม่สำเร็จ';
      });
    }
  }

  List<Equipment> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _all.where((e) {
      if (_categoryId != null && e.categoryId != _categoryId) return false;
      if (q.isEmpty) return true;
      return e.name.toLowerCase().contains(q) ||
          e.assetCode.toLowerCase().contains(q);
    }).toList();
  }

  void _toggle(int id) {
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  Future<void> _proceed() async {
    final items = _all.where((e) => _selected.contains(e.id)).toList();
    final submitted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BookingScreen(selectedItems: items, user: widget.user),
      ),
    );
    // ส่งคำขอสำเร็จแล้ว: ล้างรายการที่เลือกไว้ และโหลดรายการอุปกรณ์ใหม่
    if (submitted == true && mounted) {
      setState(_selected.clear);
      _load(showSpinner: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showBar = _tab == 0 && _selected.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: _tab == 0 ? _homeBody() : MyLoansScreen(borrowerId: widget.user.username),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            child: showBar
                ? SelectionBar(
                    count: _selected.length,
                    onClear: () => setState(_selected.clear),
                    onNext: _proceed,
                  )
                : const SizedBox(width: double.infinity),
          ),
          NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            backgroundColor: Colors.white,
            indicatorColor: AppColors.tileAvailable,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
                label: 'หน้าหลัก',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon:
                    Icon(Icons.receipt_long, color: AppColors.primary),
                label: 'รายการของฉัน',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _homeBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('ลองอีกครั้ง')),
          ],
        ),
      );
    }

    final items = _filtered;
    return RefreshIndicator(
      onRefresh: () => _load(showSpinner: false),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _greeting()),
          SliverToBoxAdapter(child: _searchField()),
          SliverToBoxAdapter(child: _categoryChips()),
          SliverToBoxAdapter(child: _sectionTitle(items.length)),
          if (items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(
                  'ไม่พบอุปกรณ์',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: 214,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final e = items[i];
                    return EquipmentCard(
                      equipment: e,
                      selected: _selected.contains(e.id),
                      onTap: () => _toggle(e.id),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _greeting() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'สวัสดี',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
                Text(
                  widget.user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          SquareIconButton(
            icon: Icons.logout_rounded,
            tooltip: 'ออกจากระบบ',
            onPressed: widget.onLogout,
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _search,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: 'ค้นหาชื่อหรือรหัสครุภัณฑ์',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(_search.clear),
                ),
        ),
      ),
    );
  }

  Widget _categoryChips() {
    Widget chip(String label, bool selected, VoidCallback onTap) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          onSelected: (_) => onTap(),
          selectedColor: AppColors.primary,
          backgroundColor: Colors.white,
          shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
          labelStyle: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.text,
          ),
        ),
      );
    }

    return SizedBox(
      height: 56,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
        children: [
          chip('ทั้งหมด', _categoryId == null,
              () => setState(() => _categoryId = null)),
          for (final c in _categories)
            chip(c.name, _categoryId == c.id,
                () => setState(() => _categoryId = c.id)),
        ],
      ),
    );
  }

  Widget _sectionTitle(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'อุปกรณ์ทั้งหมด',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              Text(
                '$count รายการ',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'แตะอุปกรณ์ที่ว่างเพื่อเลือกได้หลายชิ้น',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
