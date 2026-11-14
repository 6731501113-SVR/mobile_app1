import 'package:flutter/material.dart';

import 'models.dart';

// ---------------------------------------------------------------------------
// Equipment
// ---------------------------------------------------------------------------

IconData categoryIcon(String categoryName) {
  if (categoryName.contains('กล้อง')) return Icons.photo_camera_outlined;
  if (categoryName.contains('เสียง')) return Icons.mic_none_rounded;
  if (categoryName.contains('วิทยุ')) return Icons.cell_tower;
  return Icons.inventory_2_outlined;
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final EquipmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      EquipmentStatus.available =>
        (const Color(0xFFD8F0DF), const Color(0xFF1E6B3A), 'ว่าง'),
      EquipmentStatus.borrowed =>
        (const Color(0xFFDCE7FB), const Color(0xFF1F3F8F), 'ถูกเช่าอยู่'),
      EquipmentStatus.maintenance =>
        (const Color(0xFFFCE8BF), const Color(0xFF8A5A00), 'ซ่อมบำรุง'),
      EquipmentStatus.lost =>
        (const Color(0xFFFCE4E4), const Color(0xFF8A1F1F), 'สูญหาย'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
