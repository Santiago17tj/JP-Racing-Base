import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/core/services/factura_service.dart';
import 'package:moto_taller_app/core/services/pdf_factura_service.dart';

void main() {
  test('buildEmailBody incluye datos clave de la factura', () {
    final body = FacturaService.buildEmailBody(
      numeroOrden: 'OT-001',
      cliente: 'Ana Pérez',
      vehiculo: 'Yamaha R1',
      total: 1250.5,
      items: ['Revisión', 'Aceite'],
    );

    expect(body, contains('OT-001'));
    expect(body, contains('Ana Pérez'));
    expect(body, contains('Yamaha R1'));
    expect(body, contains('1250.50'));
  });

  test('buildInvoiceFileName genera un nombre seguro para el PDF', () {
    final name = PdfFacturaService.buildInvoiceFileName('ORDEN/001 #A');
    expect(name, 'factura_orden_001_a.pdf');
  });
}
