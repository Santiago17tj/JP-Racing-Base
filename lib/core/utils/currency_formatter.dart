import 'package:intl/intl.dart';

class CurrencyFormatter {
  // `intl` no trae datos de `es_CO` y cae en los de España, que ponen el
  // símbolo detrás («185.000 $»). En Colombia va delante: «$ 185.000». El
  // espacio es duro (U+00A0, dentro de Latin-1, así que Helvetica lo pinta en
  // el PDF) para que el símbolo nunca quede solo al final de una línea.
  static String format(double amount, {String simbolo = r'$'}) {
    final decimales = amount.truncateToDouble() == amount ? 0 : 2;
    final numero = NumberFormat.decimalPatternDigits(
      locale: 'es',
      decimalDigits: decimales,
    ).format(amount.abs());
    return '${amount < 0 ? '-' : ''}$simbolo $numero';
  }
}
