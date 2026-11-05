import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../mock/app_store.dart';
import '../models.dart';
import '../theme.dart';
import '../utils/format_utils.dart';
import '../widgets/common.dart';

/// U4: หน้าจองยืม — เลือกวัน (ปฏิทิน) วันที่ถูกจองแล้วเป็นสีแดงและเลือกไม่ได้
/// รับรายการอุปกรณ์ที่เลือกมาจากหน้าหลัก (Flutter A) ผ่าน selectedItems
/// ยืมได้สูงสุดกี่วัน (นับวันเริ่มและวันคืนรวมกัน) แก้เลขเดียวตรงนี้ได้เลย
const int maxLoanDays = 4;

class BookingScreen extends StatefulWidget {
  final List<Equipment> selectedItems;
  final AppUser user; // ผู้ยืมที่ login อยู่ (ใช้ระบุเจ้าของคำขอ)

  const BookingScreen({super.key, required this.selectedItems, required this.user});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late final List<Equipment> _items;
  final TextEditingController _purposeCtrl = TextEditingController();
  late DateTime _focusedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;

  @override
  void initState() {
    super.initState();
    _items = List.of(widget.selectedItems);
    _focusedDay = dateOnly(DateTime.now());
    _purposeCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _purposeCtrl.dispose();
    super.dispose();
  }

  /// ถ้าแตะวันเดียว (ยังไม่เลือกวันคืน) ให้ถือว่ายืมวันเดียว
  DateTime? get _effectiveEnd => _rangeEnd ?? _rangeStart;

  /// วันนี้ถูกจองแล้วหรือไม่ (ชิ้นใดชิ้นหนึ่งที่เลือกติดจอง = แดง)
  bool _isBookedDay(DateTime day) {
    final d = dateOnly(day);
    for (final item in _items) {
      final ranges = AppStore.instance
          .bookedRangesFor(item.id, myBorrowerId: widget.user.username);
      for (final r in ranges) {
        if (!d.isBefore(r.start) && !d.isAfter(r.end)) return true;
      }
    }
    return false;
  }

  /// ชิ้นที่ชนกับช่วงวันที่เลือก (กรณีเลือกคร่อมวันที่ถูกจอง)
  List<Equipment> _conflictItems() {
    final s = _rangeStart;
    final e = _effectiveEnd;
    if (s == null || e == null) return [];
    return _items.where((item) {
      final ranges = AppStore.instance
          .bookedRangesFor(item.id, myBorrowerId: widget.user.username);
      return ranges.any((r) => !e.isBefore(r.start) && !s.isAfter(r.end));
    }).toList();
  }

  void _submit() {
    final start = _rangeStart!;
    final end = _effectiveEnd!;
    final count = _items.length;
    AppStore.instance.submit(
      borrowerName: widget.user.fullName,
      borrowerId: widget.user.username,
      purpose: _purposeCtrl.text.trim(),
      start: start,
      end: end,
      items: List.of(_items),
    );
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(true); // กลับหน้าหลัก (true = ส่งคำขอสำเร็จ)
    messenger.showSnackBar(
      SnackBar(content: Text('ส่งคำขอยืม $count ชิ้นแล้ว รอผู้ดูแลอนุมัติ ดูได้ที่แท็บ "รายการของฉัน"')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = _conflictItems();
    final hasRange = _rangeStart != null;
    final canSubmit = _items.isNotEmpty &&
        _purposeCtrl.text.trim().isNotEmpty &&
        hasRange &&
        conflicts.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('จองยืมอุปกรณ์')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          _buildItemsCard(conflicts),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('วัตถุประสงค์ / ชื่องาน',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.grayText)),
                const SizedBox(height: 6),
                TextField(
                  controller: _purposeCtrl,
                  decoration: const InputDecoration(hintText: 'เช่น ถ่ายภาพงานปัจฉิมนิเทศ'),
                ),
                const SizedBox(height: 14),
                const Text('เลือกวันที่ยืม – วันที่คืน (ไม่เกิน $maxLoanDays วัน)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.grayText)),
                const SizedBox(height: 4),
                _buildCalendar(),
                const SizedBox(height: 6),
                _buildLegend(),
                const SizedBox(height: 12),
                _buildMessage(conflicts, hasRange),
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
            onPressed: canSubmit ? _submit : null,
            child: Text('ส่งคำขอยืม ${_items.length} ชิ้น'),
          ),
        ),
      ),
    );
  }

  Widget _buildItemsCard(List<Equipment> conflicts) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('รายการที่เลือก (${_items.length} ชิ้น)',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_items.isEmpty)
            const Text('ยังไม่ได้เลือกอุปกรณ์', style: TextStyle(color: AppColors.muted)),
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: conflicts.contains(item) ? AppColors.redSoft : AppColors.tealSoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      size: 22,
                      color: conflicts.contains(item) ? AppColors.redText : AppColors.teal,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(
                          conflicts.contains(item) ? '${item.assetCode} · ติดจองในช่วงนี้' : item.assetCode,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: conflicts.contains(item) ? FontWeight.w600 : FontWeight.w400,
                            color: conflicts.contains(item) ? AppColors.redText : AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'เอาออก',
                    onPressed: () => setState(() => _items.remove(item)),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final today = dateOnly(DateTime.now());
    return TableCalendar(
      locale: 'th_TH',
      firstDay: today,
      lastDay: today.add(const Duration(days: 365)),
      focusedDay: _focusedDay,
      rangeStartDay: _rangeStart,
      rangeEndDay: _rangeEnd,
      rangeSelectionMode: RangeSelectionMode.toggledOn,
      // วันที่ถูกจองแล้ว = กดเลือกไม่ได้
      enabledDayPredicate: (day) => !_isBookedDay(day),
      onRangeSelected: (start, end, focusedDay) {
        // เลือกยาวเกินกำหนด: เก็บแค่วันเริ่ม ให้เลือกวันคืนใหม่
        if (start != null && end != null) {
          final days = end.difference(start).inDays + 1;
          if (days > maxLoanDays) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ยืมได้สูงสุด $maxLoanDays วัน กรุณาเลือกวันคืนใหม่')),
            );
            setState(() {
              _rangeStart = start;
              _rangeEnd = null;
              _focusedDay = focusedDay;
            });
            return;
          }
        }
        setState(() {
          _rangeStart = start;
          _rangeEnd = end;
          _focusedDay = focusedDay;
        });
      },
      onPageChanged: (focusedDay) => _focusedDay = focusedDay,
      headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true),
      calendarStyle: CalendarStyle(
        rangeStartDecoration:
            const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
        rangeEndDecoration:
            const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
        rangeHighlightColor: AppColors.tealSoft,
        withinRangeTextStyle: const TextStyle(color: AppColors.tealDark),
        todayDecoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.teal),
        ),
        todayTextStyle: const TextStyle(color: AppColors.text),
      ),
      calendarBuilders: CalendarBuilders(
        // วันที่ถูกจองแล้ว: วงกลมสีแดงอ่อน ตัวเลขขีดฆ่า (ไม่พึ่งสีอย่างเดียว)
        disabledBuilder: (context, day, focusedDay) {
          if (!_isBookedDay(day)) return null;
          return Container(
            margin: const EdgeInsets.all(5),
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.redSoft, shape: BoxShape.circle),
            child: Text(
              '${day.day}',
              style: const TextStyle(
                color: AppColors.redText,
                decoration: TextDecoration.lineThrough,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegend() {
    Widget dot(Color c) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle),
        );
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          dot(AppColors.teal),
          const SizedBox(width: 6),
          const Text('ที่เลือก', style: TextStyle(fontSize: 12, color: AppColors.grayText)),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          dot(AppColors.redSoft),
          const SizedBox(width: 6),
          const Text('ถูกจองแล้ว (เลือกไม่ได้)',
              style: TextStyle(fontSize: 12, color: AppColors.grayText)),
        ]),
      ],
    );
  }

  Widget _buildMessage(List<Equipment> conflicts, bool hasRange) {
    if (!hasRange) {
      return const Text('แตะวันเริ่มยืม แล้วแตะวันคืน',
          style: TextStyle(fontSize: 13, color: AppColors.muted));
    }
    final s = _rangeStart!;
    final e = _effectiveEnd!;
    final range = '${thaiShort(s)} – ${thaiShort(e)}';
    if (conflicts.isNotEmpty) {
      final names = conflicts.map((c) => c.assetCode).join(', ');
      return Notice(
        background: AppColors.redSoft,
        foreground: AppColors.redText,
        icon: Icons.error_outline,
        text: 'ช่วง $range ชนกับการจองที่มีอยู่ ($names) เลือกวันอื่น หรือเอาชิ้นนั้นออกจากรายการ',
      );
    }
    return Notice(
      background: AppColors.greenSoft,
      foreground: AppColors.greenText,
      icon: Icons.check_circle_outline,
      text: 'ช่วง $range ว่างทุกชิ้น ส่งคำขอได้',
    );
  }
}
