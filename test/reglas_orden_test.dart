import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/core/dominio/reglas_orden.dart';
import 'package:moto_taller_app/data/models/orden_item.dart';

OrdenItem _item(String repuestoId, double precio,
        {int cantidad = 1, double descuento = 0}) =>
    OrdenItem(
      ordenId: 'o1',
      repuestoId: repuestoId,
      descripcion: 'x',
      cantidad: cantidad,
      precioUnitario: precio,
      descuento: descuento,
    );

/// Un UUID de verdad: Supabase rechaza cualquier otra cosa en repuesto_id.
final _uuid =
    RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$');

void main() {
  _pruebasDeDescuento();

  group('Repuestos ficticios del sistema', () {
    test('sus identificadores son UUID válidos', () {
      // Con identificadores de texto, la nube rechazaba el ítem y el detalle
      // de la orden se quedaba solo en el teléfono.
      expect(ReglasOrden.idManoObra, matches(_uuid));
      expect(ReglasOrden.idRepuestoExterno, matches(_uuid));
    });

    test('cada uno trae los datos para crearlo en el inventario', () {
      expect(ReglasOrden.especiales.keys,
          containsAll([ReglasOrden.idManoObra, ReglasOrden.idRepuestoExterno]));
      for (final datos in ReglasOrden.especiales.values) {
        expect(datos.nombre, isNotEmpty);
        expect(datos.codigo, isNotEmpty);
      }
    });

    test('se siguen reconociendo los identificadores anteriores', () {
      // Los teléfonos ya tienen ítems guardados con los ids viejos.
      expect(
          ReglasOrden.esManoObraCrudo(ReglasOrden.idManoObraAnterior), isTrue);
      expect(ReglasOrden.esEspecial(ReglasOrden.idRepuestoExternoAnterior),
          isTrue);
      expect(ReglasOrden.esEspecial('un-repuesto-cualquiera'), isFalse);
    });
  });

  group('Qué cuenta como mano de obra', () {
    test('se reconoce por el id del repuesto, no por el texto', () {
      // El nombre lo escribe el mecánico y puede decir cualquier cosa.
      final trampa = OrdenItem(
        ordenId: 'o1',
        repuestoId: 'r-normal',
        descripcion: 'Mano de obra pintura',
        cantidad: 1,
        precioUnitario: 50000,
      );
      expect(ReglasOrden.esManoObra(trampa), isFalse);
      expect(
          ReglasOrden.esManoObra(_item(ReglasOrden.idManoObra, 40000)), isTrue);
    });
  });

  group('Subtotal de repuestos', () {
    final items = [
      _item('r1', 15000),
      _item('r2', 37000, cantidad: 2),
      _item(ReglasOrden.idManoObra, 40000), // no debe sumar
    ];

    test('excluye la mano de obra para no cobrarla dos veces', () {
      expect(ReglasOrden.subtotalRepuestos(items), 89000);
      expect(ReglasOrden.manoObraDetallada(items), 40000);
    });

    test('aplica descuentos', () {
      expect(ReglasOrden.subtotalRepuestos([_item('r1', 10000, descuento: 10)]),
          9000);
    });

    test('la versión para filas de la base da el mismo número', () {
      final filas = <Map<String, Object?>>[
        {'repuesto_id': 'r1', 'cantidad': 1, 'precio_unitario': 15000},
        {'repuesto_id': 'r2', 'cantidad': 2, 'precio_unitario': 37000},
        {
          'repuesto_id': ReglasOrden.idManoObra,
          'cantidad': 1,
          'precio_unitario': 40000
        },
      ];
      expect(ReglasOrden.subtotalRepuestosCrudo(filas),
          ReglasOrden.subtotalRepuestos(items));
    });
  });

  group('Impuesto y totales', () {
    test('el IVA solo grava la mano de obra', () {
      expect(ReglasOrden.impuesto(40000, 19), 7600);
      expect(ReglasOrden.impuesto(40000, 0), 0);
    });

    test('el total suma repuestos, mano de obra e IVA de la mano de obra', () {
      expect(
        ReglasOrden.total(
            subtotalRepuestos: 67000,
            costoManoObra: 40000,
            porcentajeImpuesto: 19),
        114600,
      );
    });

    test('el saldo nunca queda negativo', () {
      expect(
          ReglasOrden.saldoPendiente(total: 100000, montoPagado: 30000), 70000);
      expect(ReglasOrden.saldoPendiente(total: 100000, montoPagado: 150000), 0);
    });
  });
}

/// El descuento tiene que aplicarse en TODAS partes o en ninguna.
///
/// Bug real encontrado el 12/08/2026: `agregarItemAOrden` recalculaba el
/// subtotal de la orden con `cantidad * precio`, sin descuento, mientras la
/// línea del ítem sí lo aplicaba. Un repuesto rebajado se cobraba de más en el
/// total, y la factura se contradecía a sí misma.
void _pruebasDeDescuento() {
  group('el descuento se respeta en el subtotal de la orden', () {
    Map<String, Object?> item(
            {required double precio, double descuento = 0, int cantidad = 1}) =>
        {
          'repuesto_id': '9f8c1a2b-3d4e-4f5a-8b9c-0d1e2f3a4b5c',
          'cantidad': cantidad,
          'precio_unitario': precio,
          'descuento': descuento,
        };

    test('sin descuento es cantidad por precio', () {
      expect(
        ReglasOrden.subtotalRepuestosCrudo([item(precio: 50000, cantidad: 2)]),
        100000,
      );
    });

    test('un 10% de descuento rebaja el subtotal', () {
      expect(
        ReglasOrden.subtotalRepuestosCrudo(
            [item(precio: 100000, descuento: 10)]),
        90000,
      );
    });

    test('el descuento no se olvida al haber varias líneas', () {
      final total = ReglasOrden.subtotalRepuestosCrudo([
        item(precio: 100000, descuento: 10), // 90.000
        item(precio: 50000, cantidad: 2), //   100.000
      ]);
      expect(total, 190000);
    });

    test('la mano de obra nunca entra: se cobraría dos veces', () {
      final total = ReglasOrden.subtotalRepuestosCrudo([
        {
          'repuesto_id': ReglasOrden.idManoObra,
          'cantidad': 1,
          'precio_unitario': 80000,
          'descuento': 0,
        },
        item(precio: 20000),
      ]);
      expect(total, 20000);
    });

    test('tampoco entra con el identificador antiguo de mano de obra', () {
      final total = ReglasOrden.subtotalRepuestosCrudo([
        {
          'repuesto_id': ReglasOrden.idManoObraAnterior,
          'cantidad': 1,
          'precio_unitario': 80000,
          'descuento': 0,
        },
      ]);
      expect(total, 0);
    });

    test('coincide con lo que calcula la propia línea del ítem', () {
      // Si estas dos cifras se separan, la factura se contradice: el detalle
      // dice una cosa y el total otra.
      const precio = 137000.0;
      const descuento = 15.0;
      final linea = OrdenItem(
        ordenId: 'o1',
        repuestoId: '9f8c1a2b-3d4e-4f5a-8b9c-0d1e2f3a4b5c',
        descripcion: 'Kit de arrastre',
        cantidad: 3,
        precioUnitario: precio,
        descuento: descuento,
      );
      final porLaRegla = ReglasOrden.subtotalRepuestosCrudo(
          [item(precio: precio, descuento: descuento, cantidad: 3)]);
      expect(porLaRegla, closeTo(linea.subtotal, 0.001));
    });
  });
}
