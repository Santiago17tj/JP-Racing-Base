import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/core/utils/currency_formatter.dart';

void main() {
  const nbsp = ' ';

  test('el símbolo va delante, como se escribe en Colombia', () {
    expect(CurrencyFormatter.format(1147500), '\$${nbsp}1.147.500');
    expect(CurrencyFormatter.format(185000), '\$${nbsp}185.000');
  });

  test('agrupa los miles también con cuatro cifras', () {
    expect(CurrencyFormatter.format(5000), '\$${nbsp}5.000');
  });

  test('cero y centavos', () {
    expect(CurrencyFormatter.format(0), '\$${nbsp}0');
    expect(CurrencyFormatter.format(1500.5), '\$${nbsp}1.500,50');
  });

  test('el signo negativo va antes del símbolo', () {
    expect(CurrencyFormatter.format(-250000), '-\$${nbsp}250.000');
  });

  test('acepta el símbolo de otra moneda', () {
    expect(CurrencyFormatter.format(120, simbolo: '€'), '€${nbsp}120');
  });

  test('todo cabe en Latin-1, que es lo único que pinta el PDF', () {
    final texto = CurrencyFormatter.format(-1234567.89);
    expect(texto.codeUnits.every((c) => c <= 0xFF), isTrue);
  });
}
