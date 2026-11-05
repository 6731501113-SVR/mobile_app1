import 'package:flutter/material.dart';

import '../../mock/app_store.dart';
import '../../models/borrow_request.dart';
import '../../models.dart';
import '../../theme.dart';
import '../../utils/format_utils.dart';
import '../../widgets/common.dart';

/// A1: แดชบอร์ด — ตัวเลขสรุป สถานะอุปกรณ์ และรายการที่ต้องดำเนินการ
class AdminDashboardScreen extends StatelessWidget {
  /// สลับไปแท็บอื่นของแอดมิน (1 = คำขอ, 2 = อุปกรณ์, 3 = รับคืน)
  final ValueChanged<int> onGoTab;

  const AdminDashboardScreen({super.key, required this.onGoTab});

  @override
  Widget build(BuildContext context) {
    final store = AppStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final borrowedItems = store.countEquipment(EquipmentStatus.borrowed);
        final available = store.countEquipment(EquipmentStatus.available);
        final actions = <BorrowRequest>[
          ...store.byStatus(RequestStatus.pending),
          ...store.requests.where((r) => r.isOverdue),
        ];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          children: [
            Row(children: [
              Expanded(
                child: _StatCard(
                  value: store.pendingCount,
                  label: 'คำขอรออนุมัติ',
                  background: AppColors.amberSoft,
                  foreground: AppColors.amberText,
                  onTap: () => onGoTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: borrowedItems,
                  label: 'กำลังถูกยืม (ชิ้น)',
                  background: AppColors.blueSoft,
                  foreground: AppColors.blueText,
                  onTap: () => onGoTab(3),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _StatCard(
                  value: store.overdueCount,
                  label: 'เกินกำหนดคืน',
                  background: AppColors.redSoft,
                  foreground: AppColors.redText,
                  onTap: () => onGoTab(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  value: available,
                  label: 'อุปกรณ์ว่าง (ชิ้น)',
                  background: AppColors.greenSoft,
                  foreground: AppColors.greenText,
                  onTap: () => onGoTab(2),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _buildStatusBar(store),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ต้องดำเนินการ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                TextButton(onPressed: () => onGoTab(1), child: const Text('ดูทั้งหมด')),
              ],
            ),
            if (actions.isEmpty)
              const AppCard(
                child: Text('ไม่มีรายการที่ต้องดำเนินการ',
                    style: TextStyle(color: AppColors.muted)),
              ),
            for (final r in actions.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ActionRow(
                  request: r,
                  onTap: () => onGoTab(r.status == RequestStatus.pending ? 1 : 3),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBar(AppStore store) {
    final total = store.equipment.length;
    final parts = [
      ('ว่าง', store.countEquipment(EquipmentStatus.available), AppColors.teal),
      ('ถูกยืม', store.countEquipment(EquipmentStatus.borrowed), const Color(0xFF2563EB)),
      ('ซ่อมบำรุง', store.countEquipment(EquipmentStatus.maintenance), const Color(0xFFD97706)),
      ('สูญหาย', store.countEquipment(EquipmentStatus.lost), AppColors.red),
    ];
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('สถานะอุปกรณ์ทั้งหมด',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              Text('$total ชิ้น', style: const TextStyle(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          if (total > 0)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    for (final p in parts)
                      if (p.$2 > 0) Expanded(flex: p.$2, child: Container(color: p.$3)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              for (final p in parts)
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: p.$3, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('${p.$1} ${p.$2}',
                      style: const TextStyle(fontSize: 12, color: AppColors.grayText)),
                ]),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final int value;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;

  const _StatCard({
    required this.value,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$value',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: foreground)),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: foreground)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final BorrowRequest request;
  final VoidCallback onTap;

  const _ActionRow({required this.request, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final overdue = r.isOverdue;
    final sub = overdue
        ? '${r.borrowerName} · เกินมา ${r.lateDays} วัน'
        : '${r.borrowerName} · ${thaiShort(r.startDate)}–${thaiShort(r.endDate)}';
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
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
                  Text(sub, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            requestStatusBadge(r),
          ],
        ),
      ),
    );
  }
}
