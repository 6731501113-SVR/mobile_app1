/// ฟังก์ชันคำนวณเงินของระบบเช่า (Dart ล้วน ไม่พึ่ง Flutter จึงเขียน unit test ได้ง่าย)
///
/// กติกาที่ใช้ (ทีมต้องยืนยันกับอาจารย์ / ผู้ดูแล):
///  - ค่าเช่า = ราคาต่อวันของทุกชิ้นรวมกัน × จำนวนวัน (นับวันเริ่มและวันคืนรวมกัน)
///  - ยอดที่ต้องจ่ายตอนเช่า = ค่าเช่า + มัดจำ
///  - ตอนรับคืน: ค่าปรับ (คืนช้า + ชดเชยความเสียหาย) หักจากมัดจำก่อน
///    ถ้าค่าปรับเกินมัดจำ ผู้เช่าจ่ายส่วนที่เกินเพิ่ม
library;

import 'format_utils.dart';

/// เวลาที่เหลือก่อนครบกำหนดชำระ (ไม่ติดลบ ถ้าเลยกำหนดแล้วได้ 0)
Duration timeLeft(DateTime due, DateTime now) {
  final d = due.difference(now);
  return d.isNegative ? Duration.zero : d;
}

/// ข้อความเวลาที่เหลือ เช่น "5 ชม. 20 นาที" / "45 นาที" / "หมดเวลาแล้ว"
String timeLeftText(Duration d) {
  if (d <= Duration.zero) return 'หมดเวลาแล้ว';
  final h = d.inHours;
  final m = d.inMinutes % 60;
  if (h == 0) return '${m < 1 ? 1 : m} นาที';
  return '$h ชม. $m นาที';
}

/// ผลการหักมัดจำตอนรับคืน
class DepositSettlement {
  /// มัดจำที่ถูกหักไป (ไม่เกินมัดจำที่มี)
  final double deducted;

  /// มัดจำที่คืนให้ผู้เช่า
  final double refund;

  /// ส่วนที่ผู้เช่าต้องจ่ายเพิ่ม (เมื่อค่าปรับเกินมัดจำ)
  final double extraDue;

  const DepositSettlement({
    required this.deducted,
    required this.refund,
    required this.extraDue,
  });

  @override
  bool operator ==(Object other) =>
      other is DepositSettlement &&
      other.deducted == deducted &&
      other.refund == refund &&
      other.extraDue == extraDue;

  @override
  int get hashCode => Object.hash(deducted, refund, extraDue);

  @override
  String toString() =>
      'DepositSettlement(deducted: $deducted, refund: $refund, extraDue: $extraDue)';
}

/// จำนวนวันเช่า นับวันเริ่มและวันคืนรวมกัน (เช่น 5 ถึง 7 = 3 วัน)
/// วันคืนก่อนวันเริ่มถือว่าไม่ถูกต้อง คืน 0
int rentalDays(DateTime start, DateTime end) {
  final diff = dateOnly(end).difference(dateOnly(start)).inDays + 1;
  return diff < 0 ? 0 : diff;
}

/// ค่าเช่า = ผลรวมราคาต่อวันของทุกชิ้น × จำนวนวัน
double rentalFee({required Iterable<double> pricesPerDay, required int days}) {
  if (days <= 0) return 0;
  final perDay = pricesPerDay.fold<double>(0, (sum, p) => sum + p);
  return perDay * days;
}

/// มัดจำรวมของทุกชิ้น
double totalDeposit(Iterable<double> deposits) =>
    deposits.fold<double>(0, (sum, d) => sum + d);

/// ค่าปรับคืนช้า = จำนวนวันที่เกิน × อัตราต่อวัน
double lateFine({required int lateDays, required double ratePerDay}) {
  if (lateDays <= 0) return 0;
  return lateDays * ratePerDay;
}

/// หักค่าปรับจากมัดจำ
/// [totalFine] = ค่าปรับคืนช้า + ค่าชดเชยความเสียหาย/สูญหาย
DepositSettlement settleDeposit({required double deposit, required double totalFine}) {
  final fine = totalFine < 0 ? 0.0 : totalFine;
  final dep = deposit < 0 ? 0.0 : deposit;
  final deducted = fine < dep ? fine : dep;
  return DepositSettlement(
    deducted: deducted,
    refund: dep - deducted,
    extraDue: fine - deducted,
  );
}
