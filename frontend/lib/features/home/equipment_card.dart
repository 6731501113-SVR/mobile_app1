import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/equipment_ui.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/theme.dart';

/// "฿300 / วัน", or a note when the item has no rental fee.
String rentalPriceLabel(Equipment e) =>
    e.pricePerDay > 0 ? '${bahtCompact(e.pricePerDay)} / วัน' : 'ไม่มีค่าเช่า';

/// "มัดจำ ฿2,000", or a note when no deposit is needed.
String depositLabel(Equipment e) =>
    e.deposit > 0 ? 'มัดจำ ${bahtCompact(e.deposit)}' : 'ไม่ต้องมัดจำ';

class EquipmentCard extends StatelessWidget {
  const EquipmentCard({
    super.key,
    required this.equipment,
    required this.selected,
    required this.onTap,
  });

  final Equipment equipment;
  final bool selected;
  final VoidCallback onTap;

  /// Fixed grid cell height (name, code, price, deposit and status chip).
  static const double height = 252;

  @override
  Widget build(BuildContext context) {
    final e = equipment;
    final enabled = e.selectable;
    final subtitle = (e.status == EquipmentStatus.borrowed && e.dueDate != null)
        ? '${e.assetCode} · คืน ${thaiShortDate(e.dueDate!)}'
        : e.assetCode;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    height: 72,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: enabled
                          ? AppColors.tileAvailable
                          : AppColors.tileMuted,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      categoryIcon(e.categoryName),
                      size: 32,
                      color: enabled ? AppColors.primary : AppColors.textMuted,
                    ),
                  ),
                  if (enabled)
                    Positioned(
                      top: 6,
                      right: 6,
                      child: _SelectDot(selected: selected),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rentalPriceLabel(e),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: enabled ? AppColors.primary : AppColors.textMuted,
                      ),
                    ),
                    Text(
                      depositLabel(e),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusChip(e.status),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectDot extends StatelessWidget {
  const _SelectDot({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.white,
        border: Border.all(
          color: selected ? AppColors.primary : const Color(0xFFB9BEBB),
          width: 1.5,
        ),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}

class SelectionBar extends StatelessWidget {
  const SelectionBar({
    super.key,
    required this.count,
    required this.onClear,
    required this.onNext,
  });

  final int count;
  final VoidCallback onClear;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'เลือกแล้ว $count ชิ้น',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(onPressed: onClear, child: const Text('ล้าง')),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 46),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            onPressed: onNext,
            child: const Text('เลือกวันที่เช่า'),
          ),
        ],
      ),
    );
  }
}
