import 'package:intl/intl.dart';

class CurrencyFormatter {
  static String format(double amount) {
    int decimalDigits = amount.truncateToDouble() == amount ? 0 : 2;
    final format = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: decimalDigits,
    );
    return format.format(amount);
  }
}
