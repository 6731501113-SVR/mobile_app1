import 'package:flutter/material.dart';

import 'borrow_models.dart';

// ---------------------------------------------------------------------------
// Borrow request status
// ---------------------------------------------------------------------------

class RequestStatusChip extends StatelessWidget {
  const RequestStatusChip(this.status, {super.key});
  final RequestStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, label) = switch (status) {
      RequestStatus.pending =>
        (const Color(0xFFFCE8BF), const Color(0xFF8A5A00), 'รออนุมัติ'),
      RequestStatus.borrowing =>
        (const Color(0xFFDCE7FB), const Color(0xFF1F3F8F), 'กำลังเช่า'),
      RequestStatus.overdue =>
        (const Color(0xFFFCE4E4), const Color(0xFFB42318), 'เกินกำหนด'),
      RequestStatus.returned =>
        (const Color(0xFFEBEBE9), const Color(0xFF4A4F4D), 'คืนแล้ว'),
      RequestStatus.rejected =>
        (const Color(0xFFFCE4E4), const Color(0xFF8A1F1F), 'ไม่อนุมัติ'),
      RequestStatus.cancelled =>
        (const Color(0xFFEBEBE9), const Color(0xFF6B7270), 'ยกเลิกแล้ว'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
