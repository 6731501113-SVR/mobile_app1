import 'package:flutter/material.dart';

import '../models/borrow_request.dart';
import '../theme.dart';
import '../utils/format_utils.dart';
import '../utils/rental_calculator.dart';
import '../widgets/common.dart';

/// U6: ค่าปรับและมัดจำของฉัน — ค่าปรับหักจากมัดจำก่อน ส่วนเกินจ่ายเงินสดที่ชมรม
class FineScreen extends StatelessWidget {
  final BorrowRequest request;

  const FineScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final settlement = settleDeposit(deposit: r.depositTotal, totalFine: r.totalFine);
    final owes = settlement.extraDue > 0;
    final paid = r.fineStatus == FineStatus.paid;
    final finedItems = r.items.where((i) => i.fineAmount > 0).toList();
    // ส่วนที่เกิน: แดงถ้ายังไม่จ่าย เขียวถ้าจ่ายแล้ว / ไม่มีส่วนเกินใช้สีเหลืองอ่อน (มีค่าปรับแต่หักมัดจำพอ)
    final bg = !owes ? AppColors.amberSoft : (paid ? AppColors.greenSoft : AppColors.redSoft);
    final fg = !owes ? AppColors.amberText : (paid ? AppColors.greenText : AppColors.redText);

    return Scaffold(
      appBar: AppBar(title: const Text('ค่าปรับและมัดจำ')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        children: [
          // กล่องสรุป: ยอดที่ต้องจ่ายเพิ่ม (ถ้ามี) หรือยอดมัดจำที่ได้คืน
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      owes ? 'ต้องจ่ายเพิ่ม' : 'คืนมัดจำให้คุณ',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: fg),
                    ),
                    if (owes)
                      StatusBadge(
                        label: paid ? 'จ่ายแล้ว' : 'ยังไม่จ่าย',
                        background: Colors.white,
                        foreground: fg,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  baht(owes ? settlement.extraDue : settlement.refund),
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: fg),
                ),
                const SizedBox(height: 4),
                Text(
                  owes
                      ? 'ค่าปรับมากกว่ามัดจำ จึงไม่มีมัดจำคืน และต้องจ่ายส่วนที่เกิน'
                      : 'ค่าปรับ ${baht(r.totalFine)} หักจากมัดจำแล้ว',
                  style: TextStyle(fontSize: 13, color: fg),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // วิธีคำนวณ
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('วิธีคำนวณ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _Line('เงินมัดจำที่จ่ายไว้', baht(r.depositTotal)),
                _Line(
                  'ค่าปรับคืนช้า (${r.lateDays} วัน × ${r.fineRatePerDay.toStringAsFixed(0)} บาท)',
                  '- ${baht(lateFine(lateDays: r.lateDays, ratePerDay: r.fineRatePerDay))}',
                ),
                if (_damageFine(r) > 0)
                  _Line('ค่าชดเชยชำรุด / สูญหาย', '- ${baht(_damageFine(r))}'),
                const Divider(height: 16),
                _Line('หักจากมัดจำ', baht(settlement.deducted)),
                _Line('มัดจำที่คืนให้', baht(settlement.refund), bold: true),
                if (owes) _Line('ต้องจ่ายเพิ่ม', baht(settlement.extraDue), bold: true),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // รายการที่ถูกปรับ
          if (finedItems.isNotEmpty) ...[
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
            const SizedBox(height: 12),
          ],

          // ขั้นตอนจ่ายส่วนที่เกิน (เฉพาะกรณียังต้องจ่ายเพิ่ม)
          if (owes && !paid)
            AppCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('วิธีชำระส่วนที่เกิน (เงินสดที่ชมรม)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  SizedBox(height: 12),
                  _Step(1, 'นำเงินสดไปจ่ายที่ [สถานที่ของชมรม] ในวัน-เวลา [วัน-เวลาทำการ]'),
                  _Step(2, 'แจ้งรหัสนักศึกษาและชื่ออุปกรณ์ให้ผู้ดูแล'),
                  _Step(3, 'ผู้ดูแลกดบันทึกว่าจ่ายแล้ว สถานะในแอปจะเปลี่ยนเป็น "จ่ายแล้ว" เอง'),
                ],
              ),
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

  /// ค่าชดเชยความเสียหาย = ค่าปรับรวม − ค่าปรับคืนช้า (ค่าปรับรวมเก็บไว้ที่ชิ้นแรกตอนรับคืน)
  static double _damageFine(BorrowRequest r) {
    final d = r.totalFine - lateFine(lateDays: r.lateDays, ratePerDay: r.fineRatePerDay);
    return d > 0 ? d : 0;
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;

  const _Line(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                    color: bold ? AppColors.text : AppColors.grayText)),
          ),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.w700 : FontWeight.w600)),
        ],
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
