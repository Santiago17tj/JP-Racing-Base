import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/core/services/respaldo_service.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';

/// El CSV que se le lleva al contador.
///
/// Antes el «Total» iba sin IVA y el «Saldo» a veces con él y a veces sin él,
/// según hubiera abonos: Total − Abonado no daba el Saldo y el total no
/// coincidía con la factura que recibió el cliente. Las cifras esperadas se
/// escriben a mano, tomadas de la factura real OT-00014.
void main() {
  OrdenMantenimiento orden({
    double repuestos = 850000,
    double manoObra = 250000,
    double pagado = 15000,
    bool cotizacion = false,
    double? saldoGuardado,
  }) =>
      OrdenMantenimiento(
        numeroOrden: 'OT-00014',
        clienteId: 'c1',
        vehiculoId: 'v1',
        tipoServicio: 'Mantenimiento',
        kilometrajeIngreso: 15000,
        subtotalRepuestos: repuestos,
        costoManoObra: manoObra,
        montoPagado: pagado,
        saldoPendiente: saldoGuardado,
        esCotizacion: cotizacion,
      );

  List<String> columnas(String csv, int fila) => csv
      .split('\n')[fila]
      .split(';')
      .map((c) => c.replaceAll('"', ''))
      .toList();

  String valor(String csv, String columna, {int fila = 1}) {
    final cabecera = columnas(csv, 0);
    return columnas(csv, fila)[cabecera.indexOf(columna)];
  }

  test('el total lleva el IVA de la mano de obra, como la factura', () {
    final csv = RespaldoService.construirCsvOrdenes([orden()],
        porcentajeImpuesto: 19);

    expect(valor(csv, 'IVA'), '47500');
    expect(valor(csv, 'Total'), '1147500');
    expect(valor(csv, 'Abonado'), '15000');
    expect(valor(csv, 'Saldo'), '1132500');
  });

  test('el saldo no depende de lo que se haya guardado en la nube', () {
    // Una orden sin abonos traía el saldo sin IVA; una con abonos, con IVA.
    // Ahora las dos salen calculadas igual.
    final csv = RespaldoService.construirCsvOrdenes(
        [orden(saldoGuardado: 0), orden(saldoGuardado: 1085000)],
        porcentajeImpuesto: 19);

    expect(valor(csv, 'Saldo', fila: 1), '1132500');
    expect(valor(csv, 'Saldo', fila: 2), '1132500');
  });

  test('las cotizaciones se distinguen de las órdenes', () {
    final csv = RespaldoService.construirCsvOrdenes(
        [orden(), orden(cotizacion: true)],
        porcentajeImpuesto: 19);

    expect(valor(csv, 'Tipo', fila: 1), 'Orden');
    expect(valor(csv, 'Tipo', fila: 2), 'Cotizacion');
  });

  test('sin «.0» y con coma decimal, para que Excel no lea miles', () {
    final csv = RespaldoService.construirCsvOrdenes(
        [orden(repuestos: 1500.5, manoObra: 0, pagado: 0)]);

    expect(valor(csv, 'Repuestos'), '1500,50');
    expect(valor(csv, 'Mano de obra'), '0');
    expect(csv, isNot(contains('.0"')));
  });
}
