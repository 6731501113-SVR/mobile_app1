import 'package:flutter/material.dart';

import '../../mock/app_store.dart';
import '../../models/borrow_request.dart';
import '../../theme.dart';
import '../../utils/format_utils.dart';
import '../../widgets/common.dart';
import 'admin_return_screen.dart';

/// A4: รายการรอรับคืน — เรียงจากเกินกำหนดนานสุด แตะเพื่อตรวจรับ
class AdminReturnsScreen extends StatefulWidget {
  const AdminReturnsScreen({super.key});

  @override
  State<AdminReturnsScreen> createState() => _AdminReturnsScreenState();
}

class _AdminReturnsScreenState extends State<AdminReturnsScreen> {
  final AppStore _store = AppStore.instance;
  final TextEditingController _search = TextEditingController();
  String _filter = 'all'; // all / overdue / today

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _isDueToday(BorrowRequest r) =>
      dateOnly(r.endDate) == dateOnly(DateTime.now());

  List<BorrowRequest> _filtered(List<BorrowRequest> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((r) {
      if (_filter == 'overdue' && !r.isOverdue) return false;
      if (_filter == 'today' && !_isDueToday(r)) return false;
      if (q.isEmpty) return true;
      return r.borrowerName.toLowerCase().contains(q) ||
          r.items.any((i) =>
              i.equipment.assetCode.toLowerCase().contains(q) ||
              i.equipment.name.toLowerCase().contains(q));
    }).toList();
  }

  Future<void> _open(BorrowRequest r) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminReturnScreen(request: r)),
    );
    if (done == true && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('บันทึกการรับคืนแล้ว')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final all = _store.toReturn;
        final overdue = all.where((r) => r.isOverdue).length;
        final today = all.where(_isDueToday).length;
        final list = _filtered(all);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'ค้นหาชื่อผู้ยืมหรือรหัสครุภัณฑ์',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(children: [
                _chip('ยังไม่คืน ${all.length}', 'all'),
                _chip('เกินกำหนด $overdue', 'overdue'),
                _chip('ครบกำหนดวันนี้ $today', 'today'),
              ]),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text('ไม่มีรายการรอรับคืน',
                          style: TextStyle(color: AppColors.muted)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: list.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == list.length) {
                          return const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              'เรียงจากเกินกำหนดนานสุดไว้บนสุด แตะรายการที่ผู้ยืมนำมาคืนเพื่อบันทึกรับคืน',
                              style: TextStyle(fontSize: 12, color: AppColors.muted),
                            ),
                          );
                        }
                        return _buildCard(list[i]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: AppColors.teal,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.text,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        ),
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _dueBadge(BorrowRequest r) {
    if (r.isOverdue) {
      return StatusBadge(
        label: 'เกิน ${r.lateDays} วัน',
        background: AppColors.redSoft,
        foreground: AppColors.redText,
      );
    }
    if (_isDueToday(r)) {
      return const StatusBadge(
        label: 'ครบวันนี้',
        background: AppColors.amberSoft,
        foreground: AppColors.amberText,
      );
    }
    final left = dateOnly(r.endDate).difference(dateOnly(DateTime.now())).inDays;
    return StatusBadge(
      label: 'เหลือ $left วัน',
      background: AppColors.graySoft,
      foreground: AppColors.grayText,
    );
  }

  Widget _buildCard(BorrowRequest r) {
    final codes = r.items.map((i) => i.equipment.assetCode).join(', ');
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _open(r),
      child: AppCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(requestTitle(r),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text('$codes · ${r.borrowerName}',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 2),
                  Text(
                    'กำหนดคืน ${thaiShort(r.endDate)}${_isDueToday(r) ? ' (วันนี้)' : ''}',
                    style: const TextStyle(fontSize: 12, color: AppColors.grayText),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _dueBadge(r),
          ],
        ),
      ),
    );
  }
}
