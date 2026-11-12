import 'package:flutter/material.dart';

import '../../core/common_widgets.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../borrow/borrow.dart';
import 'equipment_card.dart';
import 'equipment_list_controller.dart';
import 'equipment_repository.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.user,
    required this.repo,
    required this.borrowRepo,
    required this.onLogout,
  });

  final AppUser user;
  final EquipmentRepository repo;
  final BorrowRepository borrowRepo;
  final VoidCallback onLogout;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final EquipmentListController _list = EquipmentListController(widget.repo)..load();
  final _search = TextEditingController();
  int _tab = 0;
  int _requestsVersion = 0; // bump to reload the "my requests" tab

  @override
  void dispose() {
    _list.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _proceed() async {
    final items = _list.selectedItems;
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BorrowRequestPage(items: items, borrowRepo: widget.borrowRepo),
      ),
    );
    if (sent == true && mounted) {
      _list.clearSelection();
      setState(() {
        _tab = 1; // jump to "รายการของฉัน" to show the new requests
        _requestsVersion++;
      });
      _list.load(showSpinner: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _list,
      builder: (context, _) {
        final showBar = _tab == 0 && _list.selectedCount > 0;
        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: _tab == 0
                ? _homeBody()
                : MyRequestsView(
                    key: ValueKey(_requestsVersion),
                    user: widget.user,
                    repo: widget.borrowRepo,
                  ),
          ),
          bottomNavigationBar: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                child: showBar
                    ? SelectionBar(
                        count: _list.selectedCount,
                        onClear: _list.clearSelection,
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
                    selectedIcon: Icon(Icons.receipt_long, color: AppColors.primary),
                    label: 'รายการของฉัน',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _homeBody() {
    if (_list.loading) return const Center(child: CircularProgressIndicator());
    if (_list.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_list.error!),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _list.load, child: const Text('ลองอีกครั้ง')),
          ],
        ),
      );
    }

    final items = _list.visible;
    return RefreshIndicator(
      onRefresh: () => _list.load(showSpinner: false),
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
                child: Text('ไม่พบอุปกรณ์', style: TextStyle(color: AppColors.textMuted)),
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
                  mainAxisExtent: EquipmentCard.height,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final e = items[i];
                    return EquipmentCard(
                      equipment: e,
                      selected: _list.isSelected(e.id),
                      onTap: () => _list.toggle(e.id),
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
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
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
        onChanged: _list.setQuery,
        decoration: InputDecoration(
          hintText: 'ค้นหาชื่อหรือรหัสครุภัณฑ์',
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: _list.query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    _search.clear();
                    _list.setQuery('');
                  },
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
          chip('ทั้งหมด', _list.categoryId == null, () => _list.selectCategory(null)),
          for (final c in _list.categories)
            chip(c.name, _list.categoryId == c.id, () => _list.selectCategory(c.id)),
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
