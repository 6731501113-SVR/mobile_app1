import 'dart:typed_data';

import '../models.dart';
import '../utils/format_utils.dart';
import '../utils/rental_calculator.dart';

/// ตรงกับ borrow_requests.status ใน DB
enum RequestStatus { pending, approved, rejected, borrowed, returned, cancelled }

/// สถานะการชำระค่าเช่า + มัดจำ (เก็บแยกจากสถานะใบ ไม่ต้องแก้ flow เดิม)
///  unpaid        = ยังไม่จ่าย (หรืออนุมัติแล้วรอผู้เช่าจ่าย)
///  pendingReview = ผู้เช่าส่งสลิปแล้ว รอแอดมินตรวจ
///  paid          = แอดมินยืนยันแล้ว
///  rejected      = แอดมินปฏิเสธสลิป ต้องส่งใหม่
enum PaymentStatus { unpaid, pendingReview, paid, rejected }

/// สถานะค่าปรับส่วนที่เกินมัดจำ (ผู้เช่าต้องจ่ายเพิ่ม)
/// none = ไม่มีส่วนเกิน (หักจากมัดจำพอ)
enum FineStatus { none, unpaid, paid }

/// 1 ชิ้นในใบเช่า (1 แถวของตาราง borrow_items)
/// เก็บราคาและมัดจำ ณ วันที่จองไว้ที่ใบ (snapshot) เพื่อให้แอดมินแก้ราคาทีหลังแล้วใบเก่าไม่เปลี่ยน
class BorrowItem {
  final Equipment equipment;
  final String conditionBefore; // good / damaged / lost
  final String? conditionAfter;
  final double fineAmount;
  final double pricePerDay;
  final double deposit;

  BorrowItem({
    required this.equipment,
    this.conditionBefore = 'good',
    this.conditionAfter,
    this.fineAmount = 0,
    double? pricePerDay,
    double? deposit,
  })  : pricePerDay = pricePerDay ?? equipment.pricePerDay,
        deposit = deposit ?? equipment.deposit;

  factory BorrowItem.fromJson(Map<String, dynamic> json) => BorrowItem(
        equipment: Equipment.fromJson(json['equipment'] as Map<String, dynamic>),
        conditionBefore: (json['condition_before'] ?? 'good') as String,
        conditionAfter: json['condition_after'] as String?,
        fineAmount: _num(json['fine_amount']),
        pricePerDay: _num(json['price_per_day']),
        deposit: _num(json['deposit']),
      );

  Map<String, dynamic> toJson() => {
        'equipment': equipment.toJson(),
        'condition_before': conditionBefore,
        'condition_after': conditionAfter,
        'fine_amount': fineAmount,
        'price_per_day': pricePerDay,
        'deposit': deposit,
      };
}

/// ใบเช่า 1 ใบ (1 แถวของ borrow_requests + รายการใน borrow_items)
class BorrowRequest {
  final int id;
  final String purpose;
  final DateTime startDate;
  final DateTime endDate; // กำหนดคืน
  DateTime? actualReturnDate; // แอดมินกรอกตอนรับคืน
  RequestStatus status; // แก้ได้ เพราะผู้เช่ายกเลิก / แอดมินอนุมัติได้
  FineStatus fineStatus;
  final double fineRatePerDay;
  String? adminNote;
  List<BorrowItem> items;

  // --- การชำระเงิน ---
  PaymentStatus paymentStatus;
  String? slipPath; // ไฟล์สลิปที่ผู้เช่าแนบ
  String? paymentNote; // เหตุผลที่แอดมินปฏิเสธสลิป
  DateTime? paidAt;

  /// ต้องชำระภายในเวลานี้ ไม่งั้นระบบยกเลิกใบอัตโนมัติ (ตั้งตอนแอดมินอนุมัติ)
  DateTime? paymentDueAt;

  /// รูปสลิป (เก็บในหน่วยความจำเท่านั้น ไม่อยู่ใน JSON
  /// ตอนต่อ backend รูปจะถูกอัปโหลดแล้วใช้ slipPath แทน)
  Uint8List? slipBytes;

  // --- ผลการหักมัดจำ (มีค่าเมื่อรับคืนแล้ว) ---
  double? depositRefund; // มัดจำที่คืนผู้เช่า
  double extraDue; // ค่าปรับส่วนที่เกินมัดจำ ผู้เช่าต้องจ่ายเพิ่ม

  /// ชื่อและรหัสผู้เช่า (ใช้ในหน้าแอดมิน มาจาก join ตาราง users)
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
    this.paymentStatus = PaymentStatus.unpaid,
    this.slipPath,
    this.paymentNote,
    this.paidAt,
    this.paymentDueAt,
    this.slipBytes,
    this.depositRefund,
    this.extraDue = 0,
    this.borrowerName = 'สมชาย ใจดี',
    this.borrowerId = '6731500001',
  });

  // ---------------------------------------------------------------------
  // ยอดเงิน (คำนวณจากฟังก์ชันใน rental_calculator.dart)
  // ---------------------------------------------------------------------

  int get days => rentalDays(startDate, endDate);

  /// ค่าเช่าทั้งใบ
  double get rentalTotal =>
      rentalFee(pricesPerDay: items.map((i) => i.pricePerDay), days: days);

  /// มัดจำทั้งใบ
  double get depositTotal => totalDeposit(items.map((i) => i.deposit));

  /// ยอดที่ต้องจ่ายตอนเช่า = ค่าเช่า + มัดจำ
  double get amountDue => rentalTotal + depositTotal;

  /// ค่าปรับรวม (คืนช้า + ชดเชย) เก็บไว้ที่ชิ้นแรกตอนรับคืน
  double get totalFine => items.fold(0.0, (sum, i) => sum + i.fineAmount);

  /// ค่าปรับที่หักจากมัดจำ
  double get depositDeducted => settleDeposit(deposit: depositTotal, totalFine: totalFine).deducted;

  /// ผู้เช่าจ่ายเงินได้แล้วหรือยัง: อนุมัติแล้ว ยังไม่จ่าย / สลิปถูกปฏิเสธ และยังไม่เลยกำหนด
  bool get canPay =>
      status == RequestStatus.approved &&
      (paymentStatus == PaymentStatus.unpaid || paymentStatus == PaymentStatus.rejected) &&
      !isPaymentOverdue;

  /// เลยกำหนดชำระแล้วหรือยัง (ใบที่ชำระแล้ว หรือรอตรวจสลิป ไม่นับ)
  bool isPaymentOverdueAt(DateTime now) =>
      status == RequestStatus.approved &&
      (paymentStatus == PaymentStatus.unpaid || paymentStatus == PaymentStatus.rejected) &&
      paymentDueAt != null &&
      now.isAfter(paymentDueAt!);

  bool get isPaymentOverdue => isPaymentOverdueAt(DateTime.now());

  /// กำลังเช่าอยู่แต่เลยกำหนดคืนแล้ว
  bool get isOverdue =>
      status == RequestStatus.borrowed && dateOnly(endDate).isBefore(dateOnly(DateTime.now()));

  /// จำนวนวันที่เกินกำหนด (นับถึงวันคืนจริง ถ้ายังไม่คืนนับถึงวันนี้)
  int get lateDays {
    final end = actualReturnDate ?? DateTime.now();
    final diff = dateOnly(end).difference(dateOnly(endDate)).inDays;
    return diff > 0 ? diff : 0;
  }

  // ---------------------------------------------------------------------
  // JSON (ชื่อฟิลด์เป็น snake_case ถ้า backend ตั้งชื่อต่างจากนี้ แก้เฉพาะตรงนี้)
  // ---------------------------------------------------------------------

  factory BorrowRequest.fromJson(Map<String, dynamic> json) => BorrowRequest(
        id: json['id'] as int,
        purpose: (json['purpose'] ?? '') as String,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        actualReturnDate: json['actual_return_date'] == null
            ? null
            : DateTime.parse(json['actual_return_date'] as String),
        status: RequestStatus.values.byName(json['status'] as String),
        fineStatus: FineStatus.values.byName((json['fine_status'] ?? 'none') as String),
        fineRatePerDay: json['fine_rate_per_day'] == null ? 30 : _num(json['fine_rate_per_day']),
        adminNote: json['admin_note'] as String?,
        items: (json['items'] as List)
            .map((e) => BorrowItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        paymentStatus:
            PaymentStatus.values.byName((json['payment_status'] ?? 'unpaid') as String),
        slipPath: json['slip_path'] as String?,
        paymentNote: json['payment_note'] as String?,
        paidAt: json['paid_at'] == null ? null : DateTime.parse(json['paid_at'] as String),
        paymentDueAt: json['payment_due_at'] == null
            ? null
            : DateTime.parse(json['payment_due_at'] as String),
        depositRefund: json['deposit_refund'] == null ? null : _num(json['deposit_refund']),
        extraDue: _num(json['extra_due']),
        borrowerName: (json['borrower_name'] ?? '') as String,
        borrowerId: (json['borrower_id'] ?? '') as String,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'purpose': purpose,
        'start_date': _dateStr(startDate),
        'end_date': _dateStr(endDate),
        'actual_return_date':
            actualReturnDate == null ? null : _dateStr(actualReturnDate!),
        'status': status.name,
        'fine_status': fineStatus.name,
        'fine_rate_per_day': fineRatePerDay,
        'admin_note': adminNote,
        'items': items.map((i) => i.toJson()).toList(),
        'payment_status': paymentStatus.name,
        'slip_path': slipPath,
        'payment_note': paymentNote,
        'paid_at': paidAt?.toIso8601String(),
        'payment_due_at': paymentDueAt?.toIso8601String(),
        'deposit_refund': depositRefund,
        'extra_due': extraDue,
        'borrower_name': borrowerName,
        'borrower_id': borrowerId,
      };
}

/// MySQL DECIMAL มักถูกส่งมาเป็นข้อความ เช่น "150.00" จึงรองรับทั้งตัวเลขและข้อความ
double _num(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

String _dateStr(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
