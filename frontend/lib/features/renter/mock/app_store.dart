import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../models/borrow_request.dart';
import '../models.dart';
import '../utils/format_utils.dart';
import '../utils/rental_calculator.dart';

DateTime _d(int offsetDays) {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day).add(Duration(days: offsetDays));
}

/// ชื่อที่แสดงบนการ์ด เช่น "กล้อง Canon + อีก 2 ชิ้น"
String requestTitle(BorrowRequest r) {
  final first = r.items.first.equipment.name;
  return r.items.length > 1 ? '$first + อีก ${r.items.length - 1} ชิ้น' : first;
}

const _categoryNames = ['กล้อง', 'เครื่องเสียง', 'วิทยุสื่อสาร', 'แสงสว่าง'];

/// ราคาเช่าต่อวัน / มัดจำ ตั้งต้นของข้อมูลจำลอง (ตัวเลขสมมติ รอชมรมกำหนดจริง)
/// ตามหมวด: กล้อง, เครื่องเสียง, วิทยุสื่อสาร, แสงสว่าง
const _basePrice = [150.0, 100.0, 60.0, 80.0];
const _baseDeposit = [1000.0, 500.0, 300.0, 400.0];

Equipment _eq(int id, String code, String name, int categoryId,
    [EquipmentStatus status = EquipmentStatus.available]) {
  var price = _basePrice[categoryId - 1];
  var deposit = _baseDeposit[categoryId - 1];
  // อุปกรณ์เสริมราคาถูกกว่าตัวหลัก
  if (name.contains('ขาตั้ง')) {
    price = 40;
    deposit = 200;
  } else if (name.contains('สายไมค์')) {
    price = 20;
    deposit = 100;
  }
  return Equipment(
    id: id,
    assetCode: code,
    name: name,
    categoryId: categoryId,
    categoryName: _categoryNames[categoryId - 1],
    status: status,
    pricePerDay: price,
    deposit: deposit,
  );
}

/// ที่เก็บข้อมูลจำลองกลางของแอป (อยู่ในหน่วยความจำ) ใช้ร่วมกันทั้งฝั่งผู้เช่าและแอดมิน
/// ผู้เช่าส่งคำขอ → แอดมินเห็นทันที / แอดมินอนุมัติ → ผู้เช่าเห็นสถานะเปลี่ยนทันที
/// ตอนต่อ API: เปลี่ยนเมธอดข้างล่างให้เรียก API แทน แต่หน้าจอไม่ต้องแก้
class AppStore extends ChangeNotifier {
  AppStore._() {
    requests.addAll(_seedRequests());
    // ตรวจใบที่เลยกำหนดชำระทุก 30 วินาที แล้วยกเลิกอัตโนมัติ (ตอนต่อ backend งานนี้ย้ายไปเป็นงานตั้งเวลาฝั่งเซิร์ฟเวอร์)
    _expiryTimer = Timer.periodic(const Duration(seconds: 30), (_) => sweepExpired());
  }

  /// ต้องชำระภายในกี่ชั่วโมงหลังแอดมินอนุมัติ (ตัวเลขสมมติ ทีมต้องยืนยัน)
  static const Duration paymentWindow = Duration(hours: 24);

  // ignore: unused_field
  Timer? _expiryTimer;

  static final AppStore instance = AppStore._();

  /// หมวดหมู่ (id = ลำดับ + 1 ตรงกับ MockEquipmentRepository ของ A)
  final List<String> categories = ['กล้อง', 'เครื่องเสียง', 'วิทยุสื่อสาร', 'แสงสว่าง'];

  /// รายการอุปกรณ์ 6 ชิ้นแรก (id 1-6) ตรงกับ MockEquipmentRepository ใน repositories.dart
  /// ชิ้นที่ 7 ขึ้นไปเป็นของเพิ่มสำหรับให้หน้าแอดมินมีข้อมูลพอทดลอง
  final List<Equipment> equipment = [
    _eq(1, 'CAM-001', 'กล้อง Canon EOS M50', 1),
    _eq(2, 'MIC-003', 'ไมค์ไร้สาย (ชุด 2 ตัว)', 2),
    _eq(3, 'WT-005', 'วอล์กกี้ทอล์กกี้ Motorola', 3, EquipmentStatus.borrowed),
    _eq(4, 'SPK-002', 'ลำโพงบลูทูธ', 2, EquipmentStatus.maintenance),
    _eq(5, 'CAM-002', 'กล้อง Sony ZV-E10', 1),
    _eq(6, 'TRI-002', 'ขาตั้งกล้อง', 1),
    _eq(7, 'TRI-001', 'ขาตั้งกล้อง', 1, EquipmentStatus.borrowed),
    _eq(8, 'MIC-007', 'สายไมค์ XLR', 2, EquipmentStatus.borrowed),
    _eq(9, 'LGT-001', 'ไฟสตูดิโอ', 4, EquipmentStatus.borrowed),
    _eq(10, 'WT-006', 'วอล์กกี้ทอล์กกี้ Motorola', 3, EquipmentStatus.borrowed),
    _eq(11, 'WT-007', 'วอล์กกี้ทอล์กกี้ Motorola', 3, EquipmentStatus.borrowed),
    _eq(12, 'CAM-003', 'กล้อง Canon EOS M50', 1, EquipmentStatus.maintenance),
    _eq(13, 'SPK-003', 'ลำโพงบลูทูธ', 2),
    _eq(14, 'MIC-004', 'ไมค์ไร้สาย (ชุด 2 ตัว)', 2, EquipmentStatus.borrowed),
    _eq(15, 'WT-008', 'วอล์กกี้ทอล์กกี้ Motorola', 3, EquipmentStatus.lost),
  ];

  final List<BorrowRequest> requests = [];

  // ---------------------------------------------------------------------
  // ข้อมูลตั้งต้น
  // ---------------------------------------------------------------------

  Equipment byId(int id) => equipment.firstWhere((e) => e.id == id);

  List<BorrowItem> _items(List<int> ids) =>
      ids.map((id) => BorrowItem(equipment: byId(id))).toList();

  List<BorrowRequest> _seedRequests() => [
        // รออนุมัติ
        BorrowRequest(
          id: 1,
          borrowerName: 'สมชาย ใจดี',
          borrowerId: 'user123',
          purpose: 'ถ่ายภาพงานปัจฉิมนิเทศ',
          startDate: _d(8),
          endDate: _d(10),
          status: RequestStatus.pending,
          items: _items([1, 5, 6]),
        ),
        BorrowRequest(
          id: 2,
          borrowerName: 'มาลี รักเรียน',
          borrowerId: '6731500002',
          purpose: 'พิธีกรงานกีฬาสี',
          startDate: _d(11),
          endDate: _d(13),
          status: RequestStatus.pending, // ชนกับใบที่ 5 (อนุมัติแล้ว) เพื่อโชว์กรณีวันชน
          items: _items([2]),
        ),
        BorrowRequest(
          id: 3,
          borrowerName: 'ปกรณ์ แสนดี',
          borrowerId: '6731500003',
          purpose: 'เสียงงานคอนเสิร์ตเล็ก',
          startDate: _d(14),
          endDate: _d(15),
          status: RequestStatus.pending,
          items: _items([13, 6]),
        ),
        // อนุมัติแล้ว รอส่งมอบ
        BorrowRequest(
          id: 4,
          borrowerName: 'ปกรณ์ แสนดี',
          borrowerId: '6731500003',
          purpose: 'ถ่ายภาพงานรับน้อง',
          startDate: _d(4),
          endDate: _d(6),
          status: RequestStatus.approved,
          paymentStatus: PaymentStatus.paid,
          items: _items([1]),
        ),
        BorrowRequest(
          id: 5,
          borrowerName: 'กมล ศรีสุข',
          borrowerId: '6731500004',
          purpose: 'พิธีกรงานไหว้ครู',
          startDate: _d(12),
          endDate: _d(14),
          status: RequestStatus.approved,
          paymentDueAt: DateTime.now().add(const Duration(hours: 5)),
          items: _items([2]),
        ),
        // กำลังเช่า
        BorrowRequest(
          id: 6,
          borrowerName: 'มาลี รักเรียน',
          borrowerId: '6731500002',
          purpose: 'ถ่ายวิดีโอประชาสัมพันธ์',
          startDate: _d(-6),
          endDate: _d(-2),
          status: RequestStatus.borrowed,
          paymentStatus: PaymentStatus.paid,
          items: _items([7, 8]),
        ),
        BorrowRequest(
          id: 7,
          borrowerName: 'สมชาย ใจดี',
          borrowerId: 'user123',
          purpose: 'ถ่ายภาพสตูดิโอ',
          startDate: _d(-4),
          endDate: _d(-1), // เกินกำหนด 1 วัน
          status: RequestStatus.borrowed,
          paymentStatus: PaymentStatus.paid,
          items: _items([9]),
        ),
        BorrowRequest(
          id: 8,
          borrowerName: 'กมล ศรีสุข',
          borrowerId: '6731500004',
          purpose: 'พิธีกรงานเลี้ยงรุ่น',
          startDate: _d(-2),
          endDate: _d(0),
          status: RequestStatus.borrowed,
          paymentStatus: PaymentStatus.paid,
          items: _items([14]),
        ),
        BorrowRequest(
          id: 9,
          borrowerName: 'สมชาย ใจดี',
          borrowerId: 'user123',
          purpose: 'สื่อสารภาคสนามงานกีฬาสี',
          startDate: _d(-3),
          endDate: _d(3),
          status: RequestStatus.borrowed,
          paymentStatus: PaymentStatus.paid,
          items: _items([3, 10, 11]),
        ),
        // ประวัติ
        BorrowRequest(
          id: 10,
          borrowerName: 'สมชาย ใจดี',
          borrowerId: 'user123',
          purpose: 'ถ่ายภาพกิจกรรมรับน้อง',
          startDate: _d(-20),
          endDate: _d(-18),
          actualReturnDate: _d(-16),
          status: RequestStatus.returned,
          paymentStatus: PaymentStatus.paid,
          // คืนช้า 2 วัน × 30 = 60 หักจากมัดจำ 200 เหลือคืน 140 ไม่มีส่วนเกิน
          depositRefund: 140,
          items: [
            BorrowItem(equipment: byId(6), conditionAfter: 'good', fineAmount: 60),
          ],
        ),
        BorrowRequest(
          id: 11,
          borrowerName: 'สมชาย ใจดี',
          borrowerId: 'user123',
          purpose: 'พิธีกรงานกีฬาสี',
          startDate: _d(20),
          endDate: _d(22),
          status: RequestStatus.rejected,
          adminNote: 'ไมค์ถูกจองแล้วในช่วงนี้ เช่าได้หลังจากนั้น',
          items: _items([2]),
        ),
        BorrowRequest(
          id: 12,
          borrowerName: 'สมชาย ใจดี',
          borrowerId: 'user123',
          purpose: 'พิธีกรงานต้อนรับน้องใหม่',
          startDate: _d(-30),
          endDate: _d(-28),
          actualReturnDate: _d(-28),
          status: RequestStatus.returned,
          paymentStatus: PaymentStatus.paid,
          depositRefund: 500, // ไม่มีค่าปรับ คืนมัดจำเต็ม
          items: [BorrowItem(equipment: byId(2), conditionAfter: 'good')],
        ),
        // อนุมัติแล้ว รอผู้เช่าจ่ายเงิน (ไว้ลองหน้าชำระเงินด้วยบัญชี user123)
        BorrowRequest(
          id: 13,
          borrowerName: 'สมชาย ใจดี',
          borrowerId: 'user123',
          purpose: 'ลำโพงงานชมรม',
          startDate: _d(15),
          endDate: _d(16),
          status: RequestStatus.approved,
          paymentDueAt: DateTime.now().add(const Duration(hours: 20)),
          items: _items([13]),
        ),
        // คืนแล้วแต่ชำรุด ค่าชดเชยเกินมัดจำ ต้องจ่ายเพิ่ม (ไว้ลองหน้าค่าปรับ)
        BorrowRequest(
          id: 14,
          borrowerName: 'สมชาย ใจดี',
          borrowerId: 'user123',
          purpose: 'ไมค์งานรับน้อง',
          startDate: _d(-12),
          endDate: _d(-10),
          actualReturnDate: _d(-10),
          status: RequestStatus.returned,
          paymentStatus: PaymentStatus.paid,
          fineStatus: FineStatus.unpaid,
          // ชดเชย 900 หักมัดจำ 500 หมด เหลือต้องจ่ายเพิ่ม 400
          depositRefund: 0,
          extraDue: 400,
          items: [
            BorrowItem(equipment: byId(2), conditionAfter: 'damaged', fineAmount: 900),
          ],
        ),
      ];

  // ---------------------------------------------------------------------
  // ตัวเลขสรุป (แดชบอร์ด)
  // ---------------------------------------------------------------------

  List<BorrowRequest> byStatus(RequestStatus s) {
    _sweepExpired();
    return requests.where((r) => r.status == s).toList();
  }

  int get pendingCount => byStatus(RequestStatus.pending).length;
  int get approvedCount => byStatus(RequestStatus.approved).length;
  int get overdueCount => requests.where((r) => r.isOverdue).length;

  int countEquipment(EquipmentStatus s) => equipment.where((e) => e.status == s).length;

  /// ใบที่กำลังเช่าอยู่ (รอรับคืน) เรียงจากเกินกำหนดนานสุดไว้บนสุด
  List<BorrowRequest> get toReturn {
    final list = byStatus(RequestStatus.borrowed);
    list.sort((a, b) => a.endDate.compareTo(b.endDate));
    return list;
  }

  // ---------------------------------------------------------------------
  // ตรวจวันชน
  // ---------------------------------------------------------------------

  /// อุปกรณ์ในใบนี้ที่ติดกับใบอื่นที่อนุมัติแล้ว/กำลังเช่าในช่วงวันเดียวกัน
  /// (นับเฉพาะ approved / borrowed ส่วน pending ยังไม่นับ เป็นเรื่องที่ทีมต้องตกลง)
  List<Equipment> conflictsFor(BorrowRequest r) {
    final out = <Equipment>[];
    final today = dateOnly(DateTime.now());
    final rs = dateOnly(r.startDate);
    final re = dateOnly(r.endDate);
    for (final item in r.items) {
      for (final o in requests) {
        if (identical(o, r)) continue;
        if (o.status != RequestStatus.approved && o.status != RequestStatus.borrowed) continue;
        if (!o.items.any((i) => i.equipment.id == item.equipment.id)) continue;
        var oEnd = dateOnly(o.endDate);
        // ของที่ยังไม่คืนและเลยกำหนดแล้ว ถือว่าถูกยึดอยู่ถึงวันนี้
        if (o.status == RequestStatus.borrowed && oEnd.isBefore(today)) oEnd = today;
        final oStart = dateOnly(o.startDate);
        if (!re.isBefore(oStart) && !rs.isAfter(oEnd)) {
          out.add(item.equipment);
          break;
        }
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------
  // การกระทำของแอดมิน
  // ---------------------------------------------------------------------

  /// อนุมัติ (ตรวจวันชนซ้ำอีกรอบ) คืน false ถ้าชน
  bool approve(BorrowRequest r) {
    if (conflictsFor(r).isNotEmpty) return false;
    r.status = RequestStatus.approved;
    r.paymentDueAt = DateTime.now().add(paymentWindow); // เริ่มนับเวลาชำระ
    notifyListeners();
    return true;
  }

  void reject(BorrowRequest r, String reason) {
    r.status = RequestStatus.rejected;
    r.adminNote = reason.trim();
    notifyListeners();
  }

  /// ส่งมอบอุปกรณ์ให้ผู้เช่า (approved -> borrowed) ส่งมอบได้เฉพาะใบที่ชำระเงินแล้ว
  /// คืน false ถ้ายังไม่ชำระ (หน้าแอดมินใช้แจ้งเตือน)
  bool handOver(BorrowRequest r) {
    if (r.paymentStatus != PaymentStatus.paid) return false;
    r.status = RequestStatus.borrowed;
    for (final item in r.items) {
      _setStatus(item.equipment.id, EquipmentStatus.borrowed);
    }
    notifyListeners();
    return true;
  }

  // ---------------------------------------------------------------------
  // การชำระเงิน (ผู้เช่าส่งสลิป -> แอดมินตรวจ)
  // ---------------------------------------------------------------------

  /// ผู้เช่าส่งสลิป (ตอนนี้เก็บแค่ชื่อไฟล์ ตอนต่อ API จะอัปโหลดรูปจริงแล้วเก็บ path ที่ server ตอบกลับ)
  /// ส่งได้เฉพาะใบที่อนุมัติแล้วและยังไม่จ่าย / สลิปเก่าถูกปฏิเสธ
  bool submitSlip(BorrowRequest r, String slipPath, {Uint8List? bytes}) {
    if (!r.canPay) return false;
    r.slipPath = slipPath;
    r.slipBytes = bytes;
    r.paymentStatus = PaymentStatus.pendingReview;
    r.paymentNote = null;
    notifyListeners();
    return true;
  }

  /// แอดมินยืนยันว่าได้รับเงินแล้ว (ต้องรอตรวจเท่านั้น)
  bool confirmPayment(BorrowRequest r) {
    if (r.paymentStatus != PaymentStatus.pendingReview) return false;
    r.paymentStatus = PaymentStatus.paid;
    r.paidAt = DateTime.now();
    notifyListeners();
    return true;
  }

  /// แอดมินปฏิเสธสลิป (ผู้เช่าต้องส่งใหม่) ต้องมีเหตุผล
  bool rejectPayment(BorrowRequest r, String reason) {
    if (r.paymentStatus != PaymentStatus.pendingReview || reason.trim().isEmpty) return false;
    r.paymentStatus = PaymentStatus.rejected;
    r.paymentNote = reason.trim();
    // สลิปถูกปฏิเสธไม่ใช่ความผิดผู้เช่า จึงให้เวลาส่งใหม่เต็มช่วงอีกครั้ง
    r.paymentDueAt = DateTime.now().add(paymentWindow);
    notifyListeners();
    return true;
  }

  /// บันทึกรับคืน: conditions เรียงตามลำดับของ r.items ('good' / 'damaged' / 'lost')
  /// ค่าปรับรวม (เกินกำหนด + ชดเชย) เก็บไว้ที่ชิ้นแรก ส่วนชิ้นอื่นเป็น 0
  /// ค่าปรับหักจากมัดจำก่อน ส่วนที่เกินมัดจำผู้เช่าต้องจ่ายเพิ่ม
  /// [paid] = จ่ายส่วนที่เกินแล้วหรือยัง (ใช้เมื่อมีส่วนเกินเท่านั้น)
  void returnRequest(
    BorrowRequest r, {
    required List<String> conditions,
    required double extraFine,
    required bool paid,
    required DateTime returnedAt,
    String? note,
  }) {
    r.actualReturnDate = returnedAt;
    final lateAmount = lateFine(lateDays: r.lateDays, ratePerDay: r.fineRatePerDay);
    final total = lateAmount + extraFine;
    final settlement = settleDeposit(deposit: r.depositTotal, totalFine: total);

    final newItems = <BorrowItem>[];
    for (var i = 0; i < r.items.length; i++) {
      final old = r.items[i];
      newItems.add(BorrowItem(
        equipment: old.equipment,
        conditionBefore: old.conditionBefore,
        conditionAfter: conditions[i],
        fineAmount: i == 0 ? total : 0,
        pricePerDay: old.pricePerDay, // คงราคา/มัดจำ ณ วันที่จองไว้
        deposit: old.deposit,
      ));
      _setStatus(
        old.equipment.id,
        switch (conditions[i]) {
          'damaged' => EquipmentStatus.maintenance,
          'lost' => EquipmentStatus.lost,
          _ => EquipmentStatus.available,
        },
      );
    }
    r.items = newItems;
    r.status = RequestStatus.returned;
    r.depositRefund = settlement.refund;
    r.extraDue = settlement.extraDue;
    r.fineStatus = settlement.extraDue > 0
        ? (paid ? FineStatus.paid : FineStatus.unpaid)
        : FineStatus.none;
    if (note != null && note.trim().isNotEmpty) r.adminNote = note.trim();
    notifyListeners();
  }

  void setEquipmentStatus(int id, EquipmentStatus s) {
    _setStatus(id, s);
    notifyListeners();
  }

  /// คืน null ถ้าสำเร็จ หรือข้อความ error ถ้ารหัสซ้ำ
  String? addEquipment({
    required String name,
    required String code,
    required String category,
    double pricePerDay = 0,
    double deposit = 0,
  }) {
    final c = code.trim().toUpperCase();
    if (equipment.any((e) => e.assetCode.toUpperCase() == c)) {
      return 'รหัสครุภัณฑ์ $c มีอยู่แล้ว';
    }
    final nextId = equipment.fold<int>(0, (m, e) => e.id > m ? e.id : m) + 1;
    final catId = categories.indexOf(category) + 1;
    equipment.add(Equipment(
      id: nextId,
      assetCode: c,
      name: name.trim(),
      categoryId: catId < 1 ? 1 : catId,
      categoryName: category,
      status: EquipmentStatus.available,
      pricePerDay: pricePerDay,
      deposit: deposit,
    ));
    notifyListeners();
    return null;
  }

  /// รายการอุปกรณ์ที่ผู้เช่าเห็นในหน้าหลัก (ใส่วันกำหนดคืนให้ชิ้นที่ถูกเช่าอยู่)
  /// แอดมินเปลี่ยนสถานะอุปกรณ์เมื่อไหร่ ผู้เช่าจะเห็นตามเมื่อเปิดหน้าหลักใหม่
  List<Equipment> catalog() {
    return equipment.map((e) {
      if (e.status != EquipmentStatus.borrowed) return e;
      final holders = requests.where(
        (r) => r.status == RequestStatus.borrowed && r.items.any((i) => i.equipment.id == e.id),
      );
      return holders.isEmpty ? e : e.copyWith(dueDate: holders.first.endDate);
    }).toList();
  }

  // ---------------------------------------------------------------------
  // ฝั่งผู้เช่า
  // ---------------------------------------------------------------------

  /// รายการเช่าของผู้ใช้คนนั้น (ใหม่สุดก่อน)
  List<BorrowRequest> requestsOf(String borrowerId) {
    _sweepExpired();
    final list = requests.where((r) => r.borrowerId == borrowerId).toList();
    list.sort((a, b) => b.id.compareTo(a.id));
    return list;
  }

  /// ช่วงวันที่ถูกจองแล้วของอุปกรณ์ชิ้นหนึ่ง (ใช้ในปฏิทินหน้าจอง)
  /// นับเฉพาะใบที่อนุมัติแล้ว / กำลังเช่า ตรงกับที่ตรวจตอนแอดมินกดอนุมัติ
  /// ใส่ [myBorrowerId] เพื่อนับใบที่ "รออนุมัติ" ของผู้ใช้คนนั้นด้วย
  /// (กันกดขอเช่าของชิ้นเดิมในวันเดิมซ้ำๆ)
  List<DateTimeRange> bookedRangesFor(int equipmentId, {String? myBorrowerId}) {
    _sweepExpired(); // ใบที่หมดเวลาชำระถูกยกเลิกแล้ว วันที่จะว่างในปฏิทิน
    final today = dateOnly(DateTime.now());
    final out = <DateTimeRange>[];
    for (final r in requests) {
      final isMyPending = myBorrowerId != null &&
          r.status == RequestStatus.pending &&
          r.borrowerId == myBorrowerId;
      if (!isMyPending &&
          r.status != RequestStatus.approved &&
          r.status != RequestStatus.borrowed) {
        continue;
      }
      if (!r.items.any((i) => i.equipment.id == equipmentId)) continue;
      var end = dateOnly(r.endDate);
      if (r.status == RequestStatus.borrowed && end.isBefore(today)) end = today;
      out.add(DateTimeRange(start: dateOnly(r.startDate), end: end));
    }
    return out;
  }

  /// ผู้เช่าส่งคำขอใหม่ (เริ่มที่สถานะ pending) แอดมินจะเห็นในแท็บคำขอทันที
  BorrowRequest submit({
    required String borrowerName,
    required String borrowerId,
    required String purpose,
    required DateTime start,
    required DateTime end,
    required List<Equipment> items,
  }) {
    final nextId = requests.fold<int>(0, (m, r) => r.id > m ? r.id : m) + 1;
    final r = BorrowRequest(
      id: nextId,
      borrowerName: borrowerName,
      borrowerId: borrowerId,
      purpose: purpose,
      startDate: start,
      endDate: end,
      status: RequestStatus.pending,
      items: items.map((e) => BorrowItem(equipment: e)).toList(),
    );
    requests.add(r);
    notifyListeners();
    return r;
  }

  /// ผู้เช่ายกเลิกคำขอ (เปลี่ยนเป็น cancelled ไม่ลบทิ้ง ประวัติจะได้ไม่หาย)
  void cancel(BorrowRequest r) {
    r.status = RequestStatus.cancelled;
    notifyListeners();
  }

  /// ยกเลิกใบที่เลยกำหนดชำระ (อนุมัติแล้วแต่ไม่จ่าย) คืน true ถ้ามีใบถูกยกเลิก
  /// ไม่เรียก notifyListeners เพราะถูกเรียกระหว่างอ่านข้อมูลตอนสร้างหน้าจอ
  bool _sweepExpired() {
    final now = DateTime.now();
    var changed = false;
    for (final r in requests) {
      if (r.isPaymentOverdueAt(now)) {
        r.status = RequestStatus.cancelled;
        r.adminNote = 'ยกเลิกอัตโนมัติ: ไม่ชำระเงินภายในเวลาที่กำหนด';
        changed = true;
      }
    }
    return changed;
  }

  /// เรียกจาก Timer: ยกเลิกใบที่หมดเวลา แล้วแจ้งหน้าจอให้รีเฟรช
  void sweepExpired() {
    if (_sweepExpired()) notifyListeners();
  }

  void _setStatus(int id, EquipmentStatus s) {
    final i = equipment.indexWhere((e) => e.id == id);
    if (i >= 0) equipment[i] = equipment[i].copyWith(status: s);
  }
}
