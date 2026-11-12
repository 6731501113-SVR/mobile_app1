// ---------------------------------------------------------------------------
// Dates
// ---------------------------------------------------------------------------

DateTime parseDate(String iso) {
  final p = iso.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

String isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

bool sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

int dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

/// True if any day from [start] to [end] (inclusive) is in [blocked].
bool rangeHasBlocked(DateTime start, DateTime end, Set<int> blocked) {
  for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
    if (blocked.contains(dayKey(d))) return true;
  }
  return false;
}

const _thaiMonths = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

const _thaiMonthsFull = [
  'มกราคม', 'กุมภาพันธ์', 'มีนาคม', 'เมษายน', 'พฤษภาคม', 'มิถุนายน',
  'กรกฎาคม', 'สิงหาคม', 'กันยายน', 'ตุลาคม', 'พฤศจิกายน', 'ธันวาคม',
];

String thaiShortDate(DateTime d) => '${d.day} ${_thaiMonths[d.month - 1]}';

/// "พฤศจิกายน 2569" (Buddhist era)
String thaiMonthYear(DateTime d) => '${_thaiMonthsFull[d.month - 1]} ${d.year + 543}';

/// "5 พ.ย. – 7 พ.ย." (single day -> "5 พ.ย.")
String thaiDateSpan(DateTime a, DateTime b) =>
    sameDay(a, b) ? thaiShortDate(a) : '${thaiShortDate(a)} – ${thaiShortDate(b)}';

/// Compact label: "5–7 พ.ย." when in the same month.
String thaiRangeLabel(DateTime a, DateTime b) {
  if (sameDay(a, b)) return thaiShortDate(a);
  if (a.month == b.month && a.year == b.year) {
    return '${a.day}–${b.day} ${_thaiMonths[a.month - 1]}';
  }
  return '${thaiShortDate(a)} – ${thaiShortDate(b)}';
}
