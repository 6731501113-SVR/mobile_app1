import 'package:flutter/material.dart';

import '../models/borrow_request.dart';
import '../theme.dart';

/// การ์ดสีขาวขอบบางมุมโค้ง (ใช้ทุกหน้า)
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: child,
    );
  }
}

/// ป้ายสถานะเล็กๆ เช่น "รออนุมัติ"
class StatusBadge extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const StatusBadge({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: TextStyle(color: foreground, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// ป้ายสถานะของใบคำขอ (แปลงจากค่า enum ใน DB เป็นภาษาไทย)
Widget requestStatusBadge(BorrowRequest r) {
  if (r.isOverdue) {
    return const StatusBadge(
      label: 'เกินกำหนด',
      background: AppColors.redSoft,
      foreground: AppColors.redText,
    );
  }
  switch (r.status) {
    case RequestStatus.pending:
      return const StatusBadge(
          label: 'รออนุมัติ', background: AppColors.amberSoft, foreground: AppColors.amberText);
    case RequestStatus.approved:
      return const StatusBadge(
          label: 'อนุมัติแล้ว', background: AppColors.greenSoft, foreground: AppColors.greenText);
    case RequestStatus.borrowed:
      return const StatusBadge(
          label: 'กำลังเช่า', background: AppColors.blueSoft, foreground: AppColors.blueText);
    case RequestStatus.returned:
      return const StatusBadge(
          label: 'คืนแล้ว', background: AppColors.graySoft, foreground: AppColors.grayText);
    case RequestStatus.rejected:
      return const StatusBadge(
          label: 'ถูกปฏิเสธ', background: AppColors.redSoft, foreground: AppColors.redText);
    case RequestStatus.cancelled:
      return const StatusBadge(
          label: 'ยกเลิกแล้ว', background: AppColors.graySoft, foreground: AppColors.grayText);
  }
}

/// ป้ายสถานะการชำระเงินของใบเช่า
Widget paymentStatusBadge(PaymentStatus p) {
  switch (p) {
    case PaymentStatus.unpaid:
      return const StatusBadge(
          label: 'ยังไม่ชำระ', background: AppColors.amberSoft, foreground: AppColors.amberText);
    case PaymentStatus.pendingReview:
      return const StatusBadge(
          label: 'รอตรวจสลิป', background: AppColors.blueSoft, foreground: AppColors.blueText);
    case PaymentStatus.paid:
      return const StatusBadge(
          label: 'ชำระแล้ว', background: AppColors.greenSoft, foreground: AppColors.greenText);
    case PaymentStatus.rejected:
      return const StatusBadge(
          label: 'สลิปถูกปฏิเสธ', background: AppColors.redSoft, foreground: AppColors.redText);
  }
}

/// กล่องแจ้งเตือน (เขียว = ผ่าน, แดง = มีปัญหา)
class Notice extends StatelessWidget {
  final Color background;
  final Color foreground;
  final IconData icon;
  final String text;

  const Notice({
    super.key,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, height: 1.5, color: foreground)),
          ),
        ],
      ),
    );
  }
}
