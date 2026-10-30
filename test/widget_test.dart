import 'package:aster/ledger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats grouped currency', () {
    expect(formatMoney(24092.67, 'INR'), '₹24,092.67');
    expect(formatMoney(100000, 'INR'), '₹1,00,000.00');
    expect(formatMoney(7805.9, 'EUR'), '€7,805.90');
    expect(formatMoney(-34.2, 'USD', absolute: true), r'$34.20');
  });
}
