import 'package:moto_taller_app/core/utils/currency_formatter.dart';

class FacturaService {
  static String buildEmailBody({
    required String numeroOrden,
    required String cliente,
    required String vehiculo,
    required double total,
    required List<String> items,
  }) {
    final itemsText = items.join('\n- ');
    return '''
Factura de servicio
===================
Orden: $numeroOrden
Cliente: $cliente
Vehículo: $vehiculo
Total: ${CurrencyFormatter.format(total).replaceAll("\$", "")}

Items:
- $itemsText
''';
  }

  static String buildMailtoLink({
    required String to,
    required String subject,
    required String body,
  }) {
    final encodedSubject = Uri.encodeComponent(subject);
    final encodedBody = Uri.encodeComponent(body);
    return 'mailto:$to?subject=$encodedSubject&body=$encodedBody';
  }
}
