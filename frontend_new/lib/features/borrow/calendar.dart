import 'package:flutter/material.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';

/// Month calendar for picking a start–end range. Past days and [blocked]
/// days (already booked) can't be selected.
class RangeCalendar extends StatefulWidget {
  const RangeCalendar({
    super.key,
    required this.today,
    required this.blocked,
    required this.start,
    required this.end,
    required this.onTap,
  });

  final DateTime today; // date-only
  final Set<int> blocked; // dayKey()s
  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime> onTap;

  @override
  State<RangeCalendar> createState() => _RangeCalendarState();
}

class _RangeCalendarState extends State<RangeCalendar> {
  static const _weekdays = ['อา', 'จ', 'อ', 'พ', 'พฤ', 'ศ', 'ส'];
  static const _rangeColor = Color(0xFFD8EBE8);

  late DateTime _month;

  DateTime get _firstMonth => DateTime(widget.today.year, widget.today.month);

  @override
  void initState() {
    super.initState();
    _month = _firstMonth;
  }

  bool get _canPrev => _month.isAfter(_firstMonth);
  bool get _canNext =>
      _month.isBefore(DateTime(widget.today.year, widget.today.month + 12));

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = DateTime(_month.year, _month.month, 1).weekday % 7; // Sunday first

    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _canPrev ? () => _shift(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Center(
                child: Text(
                  thaiMonthYear(_month),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ),
            IconButton(
              onPressed: _canNext ? () => _shift(1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        Row(
          children: [
            for (final w in _weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.05,
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++)
              _cell(DateTime(_month.year, _month.month, d)),
          ],
        ),
      ],
    );
  }

  Widget _cell(DateTime date) {
    final s = widget.start;
    final e = widget.end;
    final past = date.isBefore(widget.today);
    final booked = !past && widget.blocked.contains(dayKey(date));
    final isStart = s != null && sameDay(date, s);
    final isEnd = e != null && sameDay(date, e);
    final hasSpan = s != null && e != null && !sameDay(s, e);
    final inRange = s != null && e != null && date.isAfter(s) && date.isBefore(e);
    final isToday = sameDay(date, widget.today);

    Color? bg;
    Color fg = past ? const Color(0xFFB9BEBB) : AppColors.text;
    BorderRadius radius = BorderRadius.zero;
    TextDecoration? deco;
    var weight = FontWeight.w400;

    if (isStart || isEnd) {
      bg = AppColors.primary;
      fg = Colors.white;
      weight = FontWeight.w700;
      const r = Radius.circular(20);
      radius = !hasSpan
          ? BorderRadius.circular(20)
          : isStart
              ? const BorderRadius.horizontal(left: r)
              : const BorderRadius.horizontal(right: r);
    } else if (inRange) {
      bg = _rangeColor;
      fg = AppColors.primary;
      weight = FontWeight.w600;
    } else if (booked) {
      bg = AppColors.dangerBg;
      fg = AppColors.danger;
      deco = TextDecoration.lineThrough;
      radius = BorderRadius.circular(10);
    }

    final selectable = !past && !booked;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: selectable ? () => widget.onTap(date) : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: isToday && bg == null
              ? Border.all(color: AppColors.primary, width: 1.2)
              : null,
        ),
        child: Text(
          '${date.day}',
          style: TextStyle(
            fontSize: 14,
            color: fg,
            fontWeight: weight,
            decoration: deco,
          ),
        ),
      ),
    );
  }
}
