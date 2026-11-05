import 'package:flutter/material.dart';

import '../models/borrow_request.dart';
import '../theme.dart';
import '../utils/format_utils.dart';
import '../widgets/common.dart';

/// U6: ค่าปรับของฉัน — ยอดเงิน วิธีคำนวณ และขั้นตอนจ่ายเงินสดที่สำนัก
class FineScreen extends StatelessWidget {
  final BorrowRequest request;

  const FineScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final paid = request.fineStatus == FineStatus.paid;
    final finedItems = request.items.where((i) => i.fineAmount > 0).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('ค่าปรับของฉัน')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          // กล่องสรุปยอด
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: paid ? AppColors.greenSoft : AppColors.redSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ยอดที่ต้องชำระ',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: paid ? AppColors.greenText : AppColors.redText,
                      ),
                    ),
                    StatusBadge(
                      label: paid ? 'จ่ายแล้ว' : 'ยังไม่จ่าย',
                      background: Colors.white,
                      foreground: paid ? AppColors.greenText : AppColors.redText,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  baht(request.totalFine),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: paid ? AppColors.greenText : AppColors.redText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'คืนเกินกำหนด ${request.lateDays} วัน × ${request.fineRatePerDay.toStringAsFixed(0)} บาท/วัน',
                  style: TextStyle(
                    fontSize: 13,
                    color: paid ? AppColors.greenText : AppColors.redText,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // รายการที่ถูกปรับ
          if (finedItems.isNotEmpty)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('รายการที่ถูกปรับ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  for (final i in finedItems)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text('${i.equipment.name} (${i.equipment.assetCode})',
                                style: const TextStyle(fontSize: 14)),
                          ),
                          Text(baht(i.fineAmount),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (finedItems.isNotEmpty) const SizedBox(height: 12),

          // ขั้นตอนการจ่าย
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('วิธีชำระ (เงินสดที่สำนัก)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 12),
                _Step(1, 'นำเงินสดไปจ่ายที่ [สถานที่ของสำนัก] ในวัน-เวลา [วัน-เวลาทำการ]'),
                _Step(2, 'แจ้งรหัสนักศึกษาและชื่ออุปกรณ์ให้ผู้ดูแล'),
                _Step(3, 'ผู้ดูแลกดบันทึกว่าจ่ายแล้ว สถานะในแอปจะเปลี่ยนเป็น "จ่ายแล้ว" เอง'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'ยังชำระผ่านแอปไม่ได้ ต้องจ่ายกับผู้ดูแลโดยตรง',
            style: TextStyle(fontSize: 13, color: AppColors.muted),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('กลับไปรายการของฉัน'),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step(this.number, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
            child: Text('$number',
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 14, height: 1.5, color: AppColors.grayText)),
          ),
        ],
      ),
    );
  }
}
