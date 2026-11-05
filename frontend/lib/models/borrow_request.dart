import '../utils/format_utils.dart';
import '../models.dart';

/// ตรงกับ borrow_requests.status ใน DB
enum RequestStatus { pending, approved, rejected, borrowed, returned, cancelled }

/// สถานะค่าปรับระดับใบคำขอ (ยังไม่มีใน DB ฉบับปัจจุบัน ต้องเพิ่มคอลัมน์ fine_status)
enum FineStatus { none, unpaid, paid }

/// 1 ชิ้นในใบคำขอ (1 แถวของตาราง borrow_items)
class BorrowItem {
  final Equipment equipment;
  final String conditionBefore; // good / damaged / lost
  final String? conditionAfter;
  final double fineAmount;

  const BorrowItem({
    required this.equipment,
    this.conditionBefore = 'good',
    this.conditionAfter,
    this.fineAmount = 0,
  });
}

/// ใบคำขอยืม 1 ใบ (1 แถวของ borrow_requests + รายการใน borrow_items)
class BorrowRequest {
  final int id;
  final String purpose;
  final DateTime startDate;
  final DateTime endDate; // กำหนดคืน
  DateTime? actualReturnDate; // แอดมินกรอกตอนรับคืน
  RequestStatus status; // แก้ได้ เพราะผู้ยืมยกเลิก / แอดมินอนุมัติได้
  FineStatus fineStatus;
  final double fineRatePerDay;
  String? adminNote;
  List<BorrowItem> items;

  /// ชื่อและรหัสผู้ยืม (ใช้ในหน้าแอดมิน มาจาก join ตาราง users)
  final String borrowerName;
  final String borrowerId;

  BorrowRequest({
    required this.id,
    required this.purpose,
    required this.startDate,
    required this.endDate,
    this.actualReturnDate,
    required this.status,
    this.fineStatus = FineStatus.none,
    this.fineRatePerDay = 30,
    this.adminNote,
    required this.items,
    this.borrowerName = 'สมชาย ใจดี',
    this.borrowerId = '6731500001',
  });

  double get totalFine => items.fold(0.0, (sum, i) => sum + i.fineAmount);

  /// กำลังยืมอยู่แต่เลยกำหนดคืนแล้ว
  bool get isOverdue =>
      status == RequestStatus.borrowed && dateOnly(endDate).isBefore(dateOnly(DateTime.now()));

  /// จำนวนวันที่เกินกำหนด (นับถึงวันคืนจริง ถ้ายังไม่คืนนับถึงวันนี้)
  int get lateDays {
    final end = actualReturnDate ?? DateTime.now();
    final diff = dateOnly(end).difference(dateOnly(endDate)).inDays;
    return diff > 0 ? diff : 0;
  }
}
