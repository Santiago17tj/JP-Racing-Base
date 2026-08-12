import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/core/services/pdf_factura_service.dart';
import 'package:moto_taller_app/data/models/cliente.dart';
import 'package:moto_taller_app/data/models/orden_item.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/data/models/vehiculo.dart';

/// Cuenta las páginas del PDF buscando los objetos /Type /Page.
int _contarPaginas(List<int> bytes) {
  final texto = String.fromCharCodes(bytes);
  return RegExp(r'/Type\s*/Page[^s]').allMatches(texto).length;
}

/// Texto plano del PDF (se genera sin comprimir para poder inspeccionarlo).
String _textoDelPdf(List<int> bytes) => String.fromCharCodes(bytes);

/// Sin espacios: el PDF divide en varios segmentos el texto que los tiene.
String _nombreRepuesto(int i) => 'ZZREP${i + 1}XX';

List<OrdenItem> _items(int cantidad) => List.generate(
      cantidad,
      (i) => OrdenItem(
        ordenId: 'o1',
        repuestoId: 'r$i',
        descripcion: _nombreRepuesto(i),
        cantidad: 2,
        precioUnitario: 35000,
      ),
    );

Future<List<int>> _factura(int cantidadItems) {
  return PdfFacturaService.construirFacturaBytes(
    comprimir: false,
    orden: OrdenMantenimiento(
      numeroOrden: 'OT-00001',
      clienteId: 'c1',
      vehiculoId: 'v1',
      tipoServicio: 'Mantenimiento Preventivo',
      kilometrajeIngreso: 85803,
      costoManoObra: 40000,
      subtotalRepuestos: 70000.0 * cantidadItems,
      diagnostico: 'Revisión general de la moto.',
    ),
    cliente: Cliente(
      nombre: 'Sonia',
      apellido: 'Vargas',
      tipoDocumento: TipoDocumento.cc,
      numeroDocumento: '37576755',
      telefono: '3166162168',
    ),
    vehiculo: Vehiculo(
      clienteId: 'c1',
      placaPatente: 'RMI33D',
      marca: 'Suzuki',
      modelo: 'Best',
      anio: 2015,
    ),
    items: _items(cantidadItems),
  );
}

/// Comprueba que ningún repuesto se quedó por fuera del PDF.
Future<void> _verificarTodosLosRepuestos(int cantidad) async {
  final bytes = await _factura(cantidad);
  final texto = _textoDelPdf(bytes);

  expect(bytes, isNotEmpty);
  for (var i = 0; i < cantidad; i++) {
    expect(texto, contains(_nombreRepuesto(i)),
        reason:
            'Falta el repuesto ${i + 1} en una factura de $cantidad repuestos');
  }
  // El bloque de totales tiene que seguir presente al final (se busca una
  // sola palabra: el PDF separa los textos con espacios en varios segmentos).
  expect(texto, contains('PAGAR'), reason: 'Se perdió el total a pagar');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('una factura corta cabe en una sola página', () async {
    final bytes = await _factura(3);
    expect(_contarPaginas(bytes), 1);
  });

  test('con 12 repuestos no se pierde ninguno', () async {
    await _verificarTodosLosRepuestos(12);
  });

  test('con 30 repuestos no se pierde ninguno y usa varias páginas', () async {
    await _verificarTodosLosRepuestos(30);
    expect(_contarPaginas(await _factura(30)), greaterThan(1));
  });

  test('aguanta 60 repuestos sin perder ninguno', () async {
    await _verificarTodosLosRepuestos(60);
  });
}
