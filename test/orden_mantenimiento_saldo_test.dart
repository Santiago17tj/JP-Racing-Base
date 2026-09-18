import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';

/// Reproduce el bug real encontrado el 17/09/2026 en la base de producción:
/// tres órdenes del cliente (100.000 / 365.000 / 1.156.000, cero abonos)
/// tenían `saldo_pendiente = 0` en la nube y se leían como pagadas.
///
/// La causa: esa columna solo se actualiza al registrar un abono
/// (`actualizarPagoOrden`). Si nunca se registró ninguno se queda en su valor
/// de creación -- 0 por DEFAULT, nunca NULL -- así que el `??` original nunca
/// se disparaba. El respaldo CSV (`RespaldoService`) lee ese campo tal cual,
/// así que reportaba "Saldo: 0" en una orden que no se había cobrado.
void main() {
  Map<String, dynamic> filaDeLaNube({
    required double costoManoObra,
    required double subtotalRepuestos,
    required double montoPagado,
    required double saldoPendiente,
    String estadoPago = 'pendiente',
  }) =>
      {
        'id': 'o1',
        'numero_orden': 'OT-00001',
        'cliente_id': 'c1',
        'vehiculo_id': 'v1',
        'estado': 'INGRESADA',
        'tipo_servicio': 'Mantenimiento Preventivo',
        'kilometraje_ingreso': 1000,
        'costo_mano_obra': costoManoObra,
        'subtotal_repuestos': subtotalRepuestos,
        'monto_pagado': montoPagado,
        'saldo_pendiente': saldoPendiente,
        'estado_pago': estadoPago,
        'fecha_ingreso': '2026-08-12T00:00:00.000',
        'created_at': '2026-08-12T00:00:00.000',
        'updated_at': '2026-08-12T00:00:00.000',
      };

  group('una orden que nunca tuvo un abono registrado', () {
    test('no se lee como pagada solo porque la nube nunca actualizó la columna',
        () {
      // OT-00001 real: 1.156.000 en total, 0 abonado, 0 guardado como saldo.
      final orden = OrdenMantenimiento.fromMap(filaDeLaNube(
        costoManoObra: 750000,
        subtotalRepuestos: 406000,
        montoPagado: 0,
        saldoPendiente: 0,
        estadoPago: 'pendiente',
      ));

      expect(orden.saldoPendiente, 1156000);
      expect(orden.estadoPago, 'pendiente');
    });

    test('una orden recién creada, de verdad en cero, sigue en cero', () {
      // total = 0: no hay nada que cobrar todavía, así que no entra en el
      // caso "sin abono registrado" (ese exige total > 0) y se respeta el
      // estado_pago tal como viene de la nube -- aquí, 'pendiente', que es el
      // DEFAULT real de la columna para una orden recién creada.
      final orden = OrdenMantenimiento.fromMap(filaDeLaNube(
        costoManoObra: 0,
        subtotalRepuestos: 0,
        montoPagado: 0,
        saldoPendiente: 0,
      ));

      expect(orden.saldoPendiente, 0);
      expect(orden.estadoPago, 'pendiente');
    });
  });

  group('una orden que sí tuvo al menos un abono', () {
    test('confía en la nube, que trae el saldo con IVA incluido', () {
      // El saldo de la nube (con IVA) puede ser mayor que total - pagado sin
      // IVA: si se recalculara aquí se perdería precisión, así que debe
      // respetarse tal cual llega.
      final orden = OrdenMantenimiento.fromMap(filaDeLaNube(
        costoManoObra: 100000,
        subtotalRepuestos: 20000,
        montoPagado: 15000,
        saldoPendiente: 132500, // incluye 19% de IVA sobre mano de obra
        estadoPago: 'parcial',
      ));

      expect(orden.saldoPendiente, 132500);
      expect(orden.estadoPago, 'parcial');
    });

    test('una orden ya saldada por completo se respeta en 0', () {
      final orden = OrdenMantenimiento.fromMap(filaDeLaNube(
        costoManoObra: 50000,
        subtotalRepuestos: 0,
        montoPagado: 50000,
        saldoPendiente: 0,
        estadoPago: 'pagado',
      ));

      expect(orden.saldoPendiente, 0);
      expect(orden.estadoPago, 'pagado');
    });
  });
}
