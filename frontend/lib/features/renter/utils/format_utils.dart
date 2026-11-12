/// ตัดเวลาออก เหลือแค่วันที่ (ใช้เทียบวันที่ให้ถูกต้อง)
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

const _thaiMonths = [
  'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
  'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.',
];

/// เช่น 5 พ.ย.
String thaiShort(DateTime d) => '${d.day} ${_thaiMonths[d.month - 1]}';

/// เช่น ฿60.00
String baht(double v) => '฿${v.toStringAsFixed(2)}';

/// เวลา เช่น 09:05
String hhmm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
