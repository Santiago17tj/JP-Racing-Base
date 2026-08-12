import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/data/database/database_helper.dart';

/// Pruebas de la capa de traducción entre la app, SQLite y Supabase.
///
/// `database_helper` tiene tres rutas de datos casi idénticas y es la mayor
/// deuda técnica del proyecto. No se puede probar entera sin una base real,
/// pero sí la parte donde vivieron todos los bugs de pérdida silenciosa: la
/// traducción de nombres y tipos entre lo que la app cree y lo que la nube
/// espera.
void main() {
  final db = DatabaseHelper.instance;

  _pruebasDeFolio();

  group('historial_stock cambia de nombre en la nube', () {
    test('ida: stock_anterior/posterior → stock_antes/despues', () {
      final r = db.prepararParaNube({
        'id': 'h1',
        'repuesto_id': 'r1',
        'stock_anterior': 10,
        'stock_posterior': 9,
      });
      expect(r['stock_antes'], 10);
      expect(r['stock_despues'], 9);
      expect(r.containsKey('stock_anterior'), isFalse);
      expect(r.containsKey('stock_posterior'), isFalse);
    });

    test('vuelta: stock_antes/despues → stock_anterior/posterior', () {
      final r = db.interpretarDeNube({
        'id': 'h1',
        'stock_antes': 10,
        'stock_despues': 9,
      });
      expect(r['stock_anterior'], 10);
      expect(r['stock_posterior'], 9);
    });

    test('ida y vuelta conserva los valores', () {
      const original = {'id': 'h1', 'stock_anterior': 42, 'stock_posterior': 7};
      final vuelta = db.interpretarDeNube(db.prepararParaNube(original));
      expect(vuelta['stock_anterior'], 42);
      expect(vuelta['stock_posterior'], 7);
    });
  });

  group('columnas calculadas por Postgres', () {
    test('subtotal nunca se envía: es GENERATED ALWAYS', () {
      final r = db.prepararParaNube({
        'id': 'i1',
        'cantidad': 2,
        'precio_unitario': 1000.0,
        'subtotal': 2000.0,
      });
      expect(r.containsKey('subtotal'), isFalse);
    });
  });

  group('booleanos: SQLite guarda 0/1, Postgres guarda true/false', () {
    test('hacia la nube, 1 se convierte en true', () {
      final r = db.prepararParaNube({'id': 'x', 'activo': 1});
      expect(r['activo'], isTrue);
    });

    test('hacia la nube, 0 se convierte en false', () {
      final r = db.prepararParaNube({'id': 'x', 'activo': 0});
      expect(r['activo'], isFalse);
    });

    test('desde la nube, true vuelve a 1', () {
      final r = db.interpretarDeNube({'id': 'x', 'activo': true});
      expect(r['activo'], 1);
    });

    test('es_cotizacion sigue la misma regla', () {
      expect(db.prepararParaNube({'es_cotizacion': 1})['es_cotizacion'], isTrue);
      expect(db.interpretarDeNube({'es_cotizacion': true})['es_cotizacion'], 1);
    });
  });

  group('vehículos: la nube tiene los dos nombres de columna', () {
    test('placa_patente se copia a placa sin perder el original', () {
      final r = db.prepararParaNube({'id': 'v', 'placa_patente': 'ABC12D'});
      expect(r['placa'], 'ABC12D');
      expect(r['placa_patente'], 'ABC12D');
    });

    test('kilometraje_actual se copia a kilometraje', () {
      final r = db.prepararParaNube({'id': 'v', 'kilometraje_actual': 15000});
      expect(r['kilometraje'], 15000);
    });

    test('vuelta: placa rellena placa_patente si falta', () {
      final r = db.interpretarDeNube({'id': 'v', 'placa': 'XYZ98A'});
      expect(r['placa_patente'], 'XYZ98A');
    });

    test('vuelta: no pisa placa_patente si ya viene', () {
      final r = db
          .interpretarDeNube({'placa': 'VIEJA1', 'placa_patente': 'NUEVA1'});
      expect(r['placa_patente'], 'NUEVA1');
    });
  });

  group('el mecánico asignado se llama distinto en cada lado', () {
    test('ida: mecanico_assigned → mecanico_asignado', () {
      final r = db.prepararParaNube({'mecanico_assigned': 'Sebastián'});
      expect(r['mecanico_asignado'], 'Sebastián');
      expect(r.containsKey('mecanico_assigned'), isFalse);
    });

    test('vuelta: mecanico_asignado → mecanico_assigned', () {
      final r = db.interpretarDeNube({'mecanico_asignado': 'Sebastián'});
      expect(r['mecanico_assigned'], 'Sebastián');
    });
  });

  group('estados de orden: la nube usa mayúsculas con guion bajo', () {
    void esperaEstado(String entrada, String salida) {
      expect(db.prepararParaNube({'estado': entrada})['estado'], salida);
    }

    test('diagnóstico', () => esperaEstado('En Diagnostico', 'EN_DIAGNOSTICO'));
    test('reparación', () => esperaEstado('En Reparacion', 'EN_REPARACION'));
    test('lista para entrega',
        () => esperaEstado('Lista para Entrega', 'LISTA_PARA_ENTREGA'));
    test('entregada', () => esperaEstado('Entregada', 'ENTREGADA'));
    test('cancelada', () => esperaEstado('Cancelada', 'CANCELADA'));
    test('cualquier otra cosa cae en INGRESADA',
        () => esperaEstado('Ingresada', 'INGRESADA'));
  });

  group('la traducción no muta el mapa que recibe', () {
    test('prepararParaNube deja intacto el original', () {
      final original = <String, dynamic>{
        'id': 'x',
        'activo': 1,
        'subtotal': 100.0,
        'stock_anterior': 5,
      };
      db.prepararParaNube(original);
      expect(original['activo'], 1);
      expect(original['subtotal'], 100.0);
      expect(original['stock_anterior'], 5);
    });

    test('interpretarDeNube deja intacto el original', () {
      final original = <String, dynamic>{'activo': true};
      db.interpretarDeNube(original);
      expect(original['activo'], isTrue);
    });
  });

  group('fecha_ingreso solo se rellena en las órdenes', () {
    // El bug más caro de todos: esto se aplicaba a CUALQUIER fila con
    // `created_at`, o sea a todas. Al bajar un repuesto de la nube se le
    // inyectaba `fecha_ingreso`, el insert local moría con «no such column», y
    // como la descarga entera iba en una sola transacción, el teléfono se
    // quedaba con CERO datos teniendo todo en la nube.

    test('una orden sí lo recibe', () {
      final r = db.interpretarDeNube({
        'numero_orden': 'OT-00001',
        'created_at': '2026-03-04T10:00:00Z',
      });
      expect(r['fecha_ingreso'], '2026-03-04T10:00:00Z');
    });

    test('una orden se reconoce también por costo_mano_obra', () {
      final r = db.interpretarDeNube({
        'costo_mano_obra': 50000,
        'created_at': '2026-03-04T10:00:00Z',
      });
      expect(r['fecha_ingreso'], '2026-03-04T10:00:00Z');
    });

    test('un repuesto NO lo recibe: su tabla no tiene esa columna', () {
      final r = db.interpretarDeNube({
        'id': 'r1',
        'codigo_interno': 'FRE-001',
        'nombre': 'Pastillas',
        'created_at': '2026-03-04T10:00:00Z',
      });
      expect(r.containsKey('fecha_ingreso'), isFalse);
    });

    test('un cliente tampoco', () {
      final r = db.interpretarDeNube({
        'id': 'c1',
        'nombre': 'Johan',
        'created_at': '2026-03-04T10:00:00Z',
      });
      expect(r.containsKey('fecha_ingreso'), isFalse);
    });

    test('si la orden ya trae fecha_ingreso, se respeta', () {
      final r = db.interpretarDeNube({
        'numero_orden': 'OT-00001',
        'created_at': '2026-03-04T10:00:00Z',
        'fecha_ingreso': '2026-01-01T08:00:00Z',
      });
      expect(r['fecha_ingreso'], '2026-01-01T08:00:00Z');
    });
  });
}

/// Numeración de órdenes. Vive aquí porque es lógica de `database_helper` y
/// porque el índice único de la nube es `(taller_id, numero_orden)`: un folio
/// repetido no es un detalle estético, es una orden que no se crea.
void _pruebasDeFolio() {
  group('siguiente número de orden', () {
    test('la primera orden del taller es OT-00001', () {
      expect(DatabaseHelper.siguienteFolio([]), 'OT-00001');
    });

    test('usa el número más alto, no el último creado', () {
      // El bug real: se tomaba la orden creada más recientemente. Si llegaba
      // una vieja después —una subida del rescate, dos equipos con la hora
      // distinta— el folio se repetía y la orden no se creaba.
      expect(
        DatabaseHelper.siguienteFolio(['OT-00014', 'OT-00003', 'OT-00009']),
        'OT-00015',
      );
    });

    test('ignora los folios de emergencia con marca de tiempo', () {
      // Sin esto, un solo folio de 13 dígitos convertía toda la serie
      // siguiente en números de 13 dígitos, para siempre.
      expect(
        DatabaseHelper.siguienteFolio(['OT-00012', 'OT-1754923410567']),
        'OT-00013',
      );
    });

    test('sobrevive a nulos y a formatos raros', () {
      expect(
        DatabaseHelper.siguienteFolio([null, '', 'ORDEN-5', 'OT-', 'OT-00007']),
        'OT-00008',
      );
    });

    test('tolera espacios alrededor', () {
      expect(DatabaseHelper.siguienteFolio([' OT-00004 ']), 'OT-00005');
    });

    test('mantiene el relleno de ceros al crecer', () {
      expect(DatabaseHelper.siguienteFolio(['OT-00099']), 'OT-00100');
      expect(DatabaseHelper.siguienteFolio(['OT-99999']), 'OT-100000');
    });
  });
}
