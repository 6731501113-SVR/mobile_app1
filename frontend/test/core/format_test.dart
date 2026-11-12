import 'package:frontend/core/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('baht always shows two decimals', () {
    expect(baht(60), '฿60.00');
    expect(baht(1234.5), '฿1,234.50');
  });

  test('bahtCompact drops decimals only for whole amounts', () {
    expect(bahtCompact(0), '฿0');
    expect(bahtCompact(300), '฿300');
    expect(bahtCompact(2000), '฿2,000');
    expect(bahtCompact(1000000), '฿1,000,000');
    expect(bahtCompact(300.5), '฿300.50');
  });
}
