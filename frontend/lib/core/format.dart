/// Money formatting (Thai baht) with thousands separators.

String _group(String digits) =>
    digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

String _fixed(double v, int decimals) {
  final parts = v.toStringAsFixed(decimals).split('.');
  return parts.length == 1 ? _group(parts[0]) : '${_group(parts[0])}.${parts[1]}';
}

/// Always two decimals: ฿60.00 (fines, amounts to pay).
String baht(double v) => '฿${_fixed(v, 2)}';

/// No decimals for whole amounts: ฿2,000, but ฿300.50 stays exact.
String bahtCompact(double v) => '฿${_fixed(v, v == v.roundToDouble() ? 0 : 2)}';
