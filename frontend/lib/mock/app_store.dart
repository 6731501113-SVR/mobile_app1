import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../models/borrow_request.dart';
import '../models.dart';
import '../utils/format_utils.dart';

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

Equipment _eq(int id, String code, String name, int categoryId,
        [EquipmentStatus status = EquipmentStatus.available]) =>
    Equipment(
      id: id,
      assetCode: code,
      name: name,
      categoryId: categoryId,
      categoryName: _categoryNames[categoryId - 1],
      status: status,
    );

/// ที่เก็บข้อมูลจำลองกลางของแอป (อยู่ในหน่วยความจำ) ใช้ร่วมกันทั้งฝั่งผู้ยืมและแอดมิน
/// ผู้ยืมส่งคำขอ → แอดมินเห็นทันที / แอดมินอนุมัติ → ผู้ยืมเห็นสถานะเปลี่ยนทันที
/// ตอนต่อ API: เปลี่ยนเมธอดข้างล่างให้เรียก API แทน แต่หน้าจอไม่ต้องแก้
class AppStore extends ChangeNotifier {
  AppStore._() {
    requests.addAll(_seedRequests());
  }

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
          items: _items([2]),
        ),
        // กำลังยืม
        BorrowRequest(
          id: 6,
          borrowerName: 'มาลี รักเรียน',
          borrowerId: '6731500002',
          purpose: 'ถ่ายวิดีโอประชาสัมพันธ์',
          startDate: _d(-6),
          endDate: _d(-2),
          status: RequestStatus.borrowed,
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
          fineStatus: FineStatus.unpaid,
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
          adminNote: 'ไมค์ถูกจองแล้วในช่วงนี้ ยืมได้หลังจากนั้น',
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
          items: [BorrowItem(equipment: byId(2), conditionAfter: 'good')],
        ),
      ];

  // ---------------------------------------------------------------------
  // ตัวเลขสรุป (แดชบอร์ด)
  // ---------------------------------------------------------------------

  List<BorrowRequest> byStatus(RequestStatus s) =>
      requests.where((r) => r.status == s).toList();

  int get pendingCount => byStatus(RequestStatus.pending).length;
  int get approvedCount => byStatus(RequestStatus.approved).length;
  int get overdueCount => requests.where((r) => r.isOverdue).length;

  int countEquipment(EquipmentStatus s) => equipment.where((e) => e.status == s).length;

  /// ใบที่กำลังยืมอยู่ (รอรับคืน) เรียงจากเกินกำหนดนานสุดไว้บนสุด
  List<BorrowRequest> get toReturn {
    final list = byStatus(RequestStatus.borrowed);
    list.sort((a, b) => a.endDate.compareTo(b.endDate));
    return list;
  }

  // ---------------------------------------------------------------------
  // ตรวจวันชน
  // ---------------------------------------------------------------------

  /// อุปกรณ์ในใบนี้ที่ติดกับใบอื่นที่อนุมัติแล้ว/กำลังยืมในช่วงวันเดียวกัน
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
    notifyListeners();
    return true;
  }

  void reject(BorrowRequest r, String reason) {
    r.status = RequestStatus.rejected;
    r.adminNote = reason.trim();
    notifyListeners();
  }

  /// ส่งมอบอุปกรณ์ให้ผู้ยืม (approved -> borrowed)
  void handOver(BorrowRequest r) {
    r.status = RequestStatus.borrowed;
    for (final item in r.items) {
      _setStatus(item.equipment.id, EquipmentStatus.borrowed);
    }
    notifyListeners();
  }

  /// บันทึกรับคืน: conditions เรียงตามลำดับของ r.items ('good' / 'damaged' / 'lost')
  /// ค่าปรับรวม (เกินกำหนด + ชดเชย) เก็บไว้ที่ชิ้นแรก ส่วนชิ้นอื่นเป็น 0
  void returnRequest(
    BorrowRequest r, {
    required List<String> conditions,
    required double extraFine,
    required bool paid,
    required DateTime returnedAt,
    String? note,
  }) {
    r.actualReturnDate = returnedAt;
    final lateFine = r.lateDays * r.fineRatePerDay;
    final total = lateFine + extraFine;

    final newItems = <BorrowItem>[];
    for (var i = 0; i < r.items.length; i++) {
      final old = r.items[i];
      newItems.add(BorrowItem(
        equipment: old.equipment,
        conditionBefore: old.conditionBefore,
        conditionAfter: conditions[i],
        fineAmount: i == 0 ? total : 0,
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
    r.fineStatus = total > 0 ? (paid ? FineStatus.paid : FineStatus.unpaid) : FineStatus.none;
    if (note != null && note.trim().isNotEmpty) r.adminNote = note.trim();
    notifyListeners();
  }

  void setEquipmentStatus(int id, EquipmentStatus s) {
    _setStatus(id, s);
    notifyListeners();
  }

  /// คืน null ถ้าสำเร็จ หรือข้อความ error ถ้ารหัสซ้ำ
  String? addEquipment({required String name, required String code, required String category}) {
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
    ));
    notifyListeners();
    return null;
  }

  /// รายการอุปกรณ์ที่ผู้ยืมเห็นในหน้าหลัก (ใส่วันกำหนดคืนให้ชิ้นที่ถูกยืมอยู่)
  /// แอดมินเปลี่ยนสถานะอุปกรณ์เมื่อไหร่ ผู้ยืมจะเห็นตามเมื่อเปิดหน้าหลักใหม่
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
  // ฝั่งผู้ยืม
  // ---------------------------------------------------------------------

  /// รายการยืมของผู้ใช้คนนั้น (ใหม่สุดก่อน)
  List<BorrowRequest> requestsOf(String borrowerId) {
    final list = requests.where((r) => r.borrowerId == borrowerId).toList();
    list.sort((a, b) => b.id.compareTo(a.id));
    return list;
  }

  /// ช่วงวันที่ถูกจองแล้วของอุปกรณ์ชิ้นหนึ่ง (ใช้ในปฏิทินหน้าจอง)
  /// นับเฉพาะใบที่อนุมัติแล้ว / กำลังยืม ตรงกับที่ตรวจตอนแอดมินกดอนุมัติ
  /// ใส่ [myBorrowerId] เพื่อนับใบที่ "รออนุมัติ" ของผู้ใช้คนนั้นด้วย
  /// (กันกดขอยืมของชิ้นเดิมในวันเดิมซ้ำๆ)
  List<DateTimeRange> bookedRangesFor(int equipmentId, {String? myBorrowerId}) {
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

  /// ผู้ยืมส่งคำขอใหม่ (เริ่มที่สถานะ pending) แอดมินจะเห็นในแท็บคำขอทันที
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

  /// ผู้ยืมยกเลิกคำขอ (เปลี่ยนเป็น cancelled ไม่ลบทิ้ง ประวัติจะได้ไม่หาย)
  void cancel(BorrowRequest r) {
    r.status = RequestStatus.cancelled;
    notifyListeners();
  }

  void _setStatus(int id, EquipmentStatus s) {
    final i = equipment.indexWhere((e) => e.id == id);
    if (i >= 0) equipment[i] = equipment[i].copyWith(status: s);
  }
}
