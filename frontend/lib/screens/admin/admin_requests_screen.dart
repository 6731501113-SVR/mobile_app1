import 'package:flutter/material.dart';

import '../../mock/app_store.dart';
import '../../models/borrow_request.dart';
import '../../theme.dart';
import '../../utils/format_utils.dart';
import '../../widgets/common.dart';

/// A2: คำขอยืม — ตรวจวันชน แล้วอนุมัติทั้งใบ หรือปฏิเสธพร้อมเหตุผล
class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  final AppStore _store = AppStore.instance;
  String _filter = 'pending'; // pending / approved / all

  List<BorrowRequest> get _filtered {
    switch (_filter) {
      case 'pending':
        return _store.byStatus(RequestStatus.pending);
      case 'approved':
        return _store.byStatus(RequestStatus.approved);
      default:
        return List.of(_store.requests);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  void _approve(BorrowRequest r) {
    final ok = _store.approve(r);
    _snack(ok ? 'อนุมัติแล้ว ${r.items.length} ชิ้น' : 'อนุมัติไม่ได้ ช่วงวันที่ชนกับคำขออื่น');
  }

  Future<void> _reject(BorrowRequest r) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (reason == null) return;
    _store.reject(r, reason);
    _snack('ปฏิเสธคำขอแล้ว');
  }

  void _handOver(BorrowRequest r) {
    _store.handOver(r);
    _snack('บันทึกการส่งมอบแล้ว');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _store,
      builder: (context, _) {
        final list = _filtered;
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(children: [
                _chip('รออนุมัติ ${_store.pendingCount}', 'pending'),
                _chip('อนุมัติแล้ว ${_store.approvedCount}', 'approved'),
                _chip('ทั้งหมด', 'all'),
              ]),
            ),
            Expanded(
              child: list.isEmpty
                  ? const Center(
                      child: Text('ไม่มีรายการ', style: TextStyle(color: AppColors.muted)))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _buildCard(list[i]),
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

  Widget _buildCard(BorrowRequest r) {
    final conflicts = _store.conflictsFor(r);
    final isPending = r.status == RequestStatus.pending;
    final isApproved = r.status == RequestStatus.approved;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.borrowerName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('${r.borrowerId} · ${r.purpose}',
                        style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              requestStatusBadge(r),
            ],
          ),
          const SizedBox(height: 8),
          Text('ช่วงยืม: ${thaiShort(r.startDate)} – ${thaiShort(r.endDate)}',
              style: const TextStyle(fontSize: 13, color: AppColors.grayText)),
          const SizedBox(height: 8),
          Text('อุปกรณ์ ${r.items.length} ชิ้น',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          for (final i in r.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                '• ${i.equipment.name} · ${i.equipment.assetCode}',
                style: TextStyle(
                  fontSize: 13,
                  color: conflicts.any((c) => c.id == i.equipment.id)
                      ? AppColors.redText
                      : AppColors.grayText,
                  fontWeight: conflicts.any((c) => c.id == i.equipment.id)
                      ? FontWeight.w600
                      : FontWeight.w400,
                ),
              ),
            ),
          if (isPending) ...[
            const SizedBox(height: 8),
            if (conflicts.isEmpty)
              Notice(
                background: AppColors.greenSoft,
                foreground: AppColors.greenText,
                icon: Icons.check_circle_outline,
                text: r.items.length > 1
                    ? 'ตรวจซ้ำแล้ว ทั้ง ${r.items.length} ชิ้นว่างในช่วงนี้'
                    : 'ตรวจซ้ำแล้ว ว่างในช่วงนี้',
              )
            else
              Notice(
                background: AppColors.redSoft,
                foreground: AppColors.redText,
                icon: Icons.error_outline,
                text:
                    'ชนกับคำขอที่อนุมัติแล้ว: ${conflicts.map((c) => c.assetCode).join(', ')} '
                    'อนุมัติไม่ได้ ให้ปฏิเสธพร้อมแจ้งเหตุผล',
              ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: AppColors.red,
                  ),
                  onPressed: () => _reject(r),
                  child: const Text('ปฏิเสธ'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                  onPressed: conflicts.isEmpty ? () => _approve(r) : null,
                  child: Text(r.items.length > 1 ? 'อนุมัติทั้งหมด' : 'อนุมัติ'),
                ),
              ),
            ]),
          ],
          if (isApproved) ...[
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(44)),
              onPressed: () => _handOver(r),
              child: const Text('ส่งมอบอุปกรณ์'),
            ),
          ],
          if (r.status == RequestStatus.rejected && r.adminNote != null) ...[
            const SizedBox(height: 8),
            Notice(
              background: AppColors.redSoft,
              foreground: AppColors.redText,
              icon: Icons.info_outline,
              text: 'เหตุผล: ${r.adminNote}',
            ),
          ],
        ],
      ),
    );
  }
}

/// กล่องกรอกเหตุผลที่ปฏิเสธ (ต้องกรอก ผู้ยืมจะเห็นในหน้ารายการของฉัน)
class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  static const _quick = [
    'อุปกรณ์ถูกจองแล้วในช่วงนี้',
    'อุปกรณ์ไม่พร้อมใช้งาน',
    'วัตถุประสงค์ไม่เหมาะสม',
  ];
  final TextEditingController _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _ctrl.text.trim().isNotEmpty;
    return AlertDialog(
      title: const Text('ปฏิเสธคำขอ'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ระบุเหตุผล ผู้ยืมจะเห็นข้อความนี้',
              style: TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in _quick)
                ActionChip(
                  label: Text(q, style: const TextStyle(fontSize: 12)),
                  onPressed: () => _ctrl.text = q,
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ctrl,
            maxLines: 2,
            decoration: const InputDecoration(hintText: 'เหตุผล'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('ยกเลิก')),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: AppColors.red,
          ),
          onPressed: canSubmit ? () => Navigator.of(context).pop(_ctrl.text.trim()) : null,
          child: const Text('ปฏิเสธคำขอ'),
        ),
      ],
    );
  }
}
