import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/core/dominio/reglas_orden.dart';
import 'package:moto_taller_app/core/services/pdf_factura_service.dart';
import 'package:moto_taller_app/data/models/orden_item.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/data/models/perfil_taller.dart';

/// Las cifras del recuadro de totales de la factura.
///
/// `factura_muchos_repuestos_test` comprueba que no se pierdan líneas; esto
/// comprueba que los **números** sean los correctos.
///
/// Importa porque el 12/08/2026 aparecieron cuatro sitios que recalculaban el
/// subtotal de la orden ignorando el descuento. La factura se contradecía a sí
/// misma: la línea del repuesto mostraba el precio rebajado y el total cobraba
/// el completo. Ese error se descubre discutiendo con un cliente en el
/// mostrador, que es el peor sitio posible.
void main() {
  _pruebasDeSaldo();

  OrdenItem repuesto({
    required double precio,
    double descuento = 0,
    int cantidad = 1,
  }) =>
      OrdenItem(
        ordenId: 'o1',
        repuestoId: '9f8c1a2b-3d4e-4f5a-8b9c-0d1e2f3a4b5c',
        descripcion: 'Cadena 520',
        cantidad: cantidad,
        precioUnitario: precio,
        descuento: descuento,
      );

  OrdenItem manoDeObra(double monto) => OrdenItem(
        ordenId: 'o1',
        repuestoId: ReglasOrden.idManoObra,
        descripcion: 'Ajuste general',
        cantidad: 1,
        precioUnitario: monto,
      );

  TotalesFactura totales({
    required List<OrdenItem> items,
    double costoManoObra = 0,
    double porcentajeImpuesto = 0,
  }) =>
      TotalesFactura.de(
        orden: OrdenMantenimiento(
          numeroOrden: 'OT-00099',
          clienteId: 'c1',
          vehiculoId: 'v1',
          tipoServicio: 'Mantenimiento Preventivo',
          kilometrajeIngreso: 42000,
          costoManoObra: costoManoObra,
        ),
        items: items,
        taller: PerfilTaller(
          usuarioAdministradorId: 'u1',
          nombreTaller: 'JP RACING',
          porcentajeImpuestoDefecto: porcentajeImpuesto,
        ),
      );

  group('el descuento llega hasta el total de la factura', () {
    test('un repuesto con 20% de descuento se cobra rebajado', () {
      final t = totales(items: [repuesto(precio: 100000, descuento: 20)]);
      expect(t.repuestos, 80000);
      expect(t.total, 80000,
          reason: 'Se está cobrando el precio sin descontar: el cliente paga '
              'de más y el detalle de la factura dice otra cosa.');
    });

    test('varias líneas, unas con descuento y otras sin él', () {
      final t = totales(items: [
        repuesto(precio: 100000, descuento: 10), //  90.000
        repuesto(precio: 25000, cantidad: 2), //     50.000
      ], costoManoObra: 60000);

      expect(t.repuestos, 140000);
      expect(t.manoObra, 60000);
      expect(t.total, 200000);
    });

    test('un descuento del 100% deja la línea en cero', () {
      final t = totales(items: [repuesto(precio: 50000, descuento: 100)]);
      expect(t.repuestos, 0);
    });
  });

  group('el IVA solo grava la mano de obra', () {
    test('sin mano de obra el IVA es cero aunque haya repuestos', () {
      // Es el caso de la factura real OT-00014: una cadena de 89.000, mano de
      // obra 0, IVA 0, total 89.000.
      final t =
          totales(items: [repuesto(precio: 89000)], porcentajeImpuesto: 19);

      expect(t.impuesto, 0,
          reason: 'Se está gravando el repuesto. Los repuestos ya se venden '
              'con el impuesto incluido: cobrarlo otra vez es cobrarlo dos '
              'veces.');
      expect(t.total, 89000);
    });

    test('se calcula sobre la mano de obra, no sobre el subtotal', () {
      final t = totales(
        items: [repuesto(precio: 100000)],
        costoManoObra: 50000,
        porcentajeImpuesto: 19,
      );

      expect(t.impuesto, 9500); // 19% de 50.000, no de 150.000
      expect(t.subtotal, 150000);
      expect(t.total, 159500);
    });

    test('con el impuesto en cero el total no cambia', () {
      final t = totales(
        items: [repuesto(precio: 100000)],
        costoManoObra: 50000,
      );
      expect(t.impuesto, 0);
      expect(t.total, 150000);
    });
  });

  group('la mano de obra no se cobra dos veces', () {
    test('su línea sale en la tabla pero no suma al subtotal de repuestos', () {
      // La mano de obra se guarda como ítem para que aparezca detallada en la
      // factura, pero su valor real vive en `orden.costoManoObra`.
      final t = totales(
        items: [repuesto(precio: 40000), manoDeObra(70000)],
        costoManoObra: 70000,
      );

      expect(t.repuestos, 40000,
          reason: 'El ítem de mano de obra entró en el subtotal de repuestos.');
      expect(t.total, 110000,
          reason: '180.000 sería cobrarla dos veces: desde su línea y desde '
              'costoManoObra.');
    });

    test('también con el identificador antiguo de mano de obra', () {
      // Hay ítems guardados en los teléfonos con el id anterior al cambio a
      // UUID. Siguen siendo mano de obra y tampoco deben sumar.
      final t = totales(
        items: [
          repuesto(precio: 40000),
          OrdenItem(
            ordenId: 'o1',
            repuestoId: ReglasOrden.idManoObraAnterior,
            descripcion: 'Ajuste',
            cantidad: 1,
            precioUnitario: 70000,
          ),
        ],
        costoManoObra: 70000,
      );
      expect(t.repuestos, 40000);
      expect(t.total, 110000);
    });
  });

  group('casos límite', () {
    test('una factura sin nada da cero, no un error', () {
      final t = totales(items: []);
      expect(t.repuestos, 0);
      expect(t.total, 0);
    });

    test('solo mano de obra, sin repuestos', () {
      final t = totales(items: [], costoManoObra: 80000, porcentajeImpuesto: 19);
      expect(t.repuestos, 0);
      expect(t.impuesto, closeTo(15200, 0.001));
      expect(t.total, closeTo(95200, 0.001));
    });
  });
}

/// El saldo pendiente que aparece en la factura.
///
/// Caso real, factura OT-00014 del 12/08/2026: repuestos 850.000, mano de obra
/// 250.000, IVA 47.500, total 1.147.500, abonado 15.000. La factura imprimía
/// **1.085.000** de saldo cuando lo correcto son 1.132.500. Exactamente el IVA
/// de diferencia, en contra del taller.
///
/// La causa: se imprimía `orden.saldoPendiente`, un campo guardado que se
/// calcula sobre `totalEstimado` — la suma SIN impuesto. La pantalla de la
/// orden usaba `saldoPendienteConImpuesto` y mostraba el número correcto, así
/// que la app y su propia factura decían cosas distintas.
void _pruebasDeSaldo() {
  TotalesFactura conAbono({
    required List<OrdenItem> items,
    required double costoManoObra,
    required double montoPagado,
    double porcentajeImpuesto = 0,
  }) =>
      TotalesFactura.de(
        orden: OrdenMantenimiento(
          numeroOrden: 'OT-00014',
          clienteId: 'c1',
          vehiculoId: 'v1',
          tipoServicio: 'Mantenimiento Preventivo',
          kilometrajeIngreso: 42000,
          costoManoObra: costoManoObra,
          subtotalRepuestos: ReglasOrden.subtotalRepuestos(items),
          montoPagado: montoPagado,
        ),
        items: items,
        taller: PerfilTaller(
          usuarioAdministradorId: 'u1',
          nombreTaller: 'JP RACING',
          porcentajeImpuestoDefecto: porcentajeImpuesto,
        ),
      );

  OrdenItem rep(double precio) => OrdenItem(
        ordenId: 'o1',
        repuestoId: '9f8c1a2b-3d4e-4f5a-8b9c-0d1e2f3a4b5c',
        descripcion: 'Repuesto',
        cantidad: 1,
        precioUnitario: precio,
      );

  group('el saldo pendiente incluye el IVA', () {
    test('reproduce la factura OT-00014 con el número correcto', () {
      final t = conAbono(
        items: [rep(850000)],
        costoManoObra: 250000,
        montoPagado: 15000,
        porcentajeImpuesto: 19,
      );

      expect(t.total, 1147500);
      expect(t.saldoPendiente, 1132500,
          reason: '1.085.000 sería el saldo sin contar el IVA: el taller '
              'cobraría 47.500 pesos de menos.');
    });

    test('sin impuesto el saldo es total menos abonado', () {
      final t = conAbono(
        items: [rep(100000)],
        costoManoObra: 50000,
        montoPagado: 30000,
      );
      expect(t.saldoPendiente, 120000);
    });

    test('si ya pagó de más el saldo es cero, nunca negativo', () {
      final t = conAbono(
        items: [rep(50000)],
        costoManoObra: 0,
        montoPagado: 80000,
      );
      expect(t.saldoPendiente, 0);
    });

    test('sin abonos el saldo es el total completo', () {
      final t = conAbono(
        items: [rep(100000)],
        costoManoObra: 100000,
        montoPagado: 0,
        porcentajeImpuesto: 19,
      );
      expect(t.saldoPendiente, t.total);
      expect(t.saldoPendiente, 219000);
    });
  });
}
