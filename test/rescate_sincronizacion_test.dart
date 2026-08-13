import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/core/dominio/reglas_orden.dart';
import 'package:moto_taller_app/core/services/rescate_sincronizacion_service.dart';

/// Pruebas de la lógica que decide **qué** se sube y **cómo se traduce**.
///
/// Cada grupo corresponde a una de las trampas que hicieron fracasar la
/// sincronización durante meses. La parte de red no se prueba aquí: se verifica
/// contando filas en Supabase después de ejecutar la subida en el teléfono.
void main() {
  _pruebasDeOtraCuenta();
  _pruebasDeOrdenPropia();

  group('traducción de identificadores antiguos', () {
    test('el id viejo de mano de obra se convierte al UUID nuevo', () {
      expect(
        RescateSincronizacionService.repuestoIdParaNube(
            ReglasOrden.idManoObraAnterior),
        ReglasOrden.idManoObra,
      );
    });

    test('el id viejo de repuesto externo se convierte al UUID nuevo', () {
      expect(
        RescateSincronizacionService.repuestoIdParaNube(
            ReglasOrden.idRepuestoExternoAnterior),
        ReglasOrden.idRepuestoExterno,
      );
    });

    test('un UUID normal de inventario se deja intacto', () {
      const idReal = '9f8c1a2b-3d4e-4f5a-8b9c-0d1e2f3a4b5c';
      expect(RescateSincronizacionService.repuestoIdParaNube(idReal), idReal);
    });

    test('los UUID nuevos pasan sin cambios (subida reejecutable)', () {
      expect(
        RescateSincronizacionService.repuestoIdParaNube(ReglasOrden.idManoObra),
        ReglasOrden.idManoObra,
      );
    });
  });

  group('normalización de una fila antes de compararla con la nube', () {
    const uuidOrden = '11111111-1111-4111-8111-111111111111';

    Map<String, Object?> item({required String repuestoId}) => {
          'id': '22222222-2222-4222-8222-222222222222',
          'orden_id': uuidOrden,
          'repuesto_id': repuestoId,
          'descripcion': 'Cambio de aceite',
          'cantidad': 1,
          'precio_unitario': 45000.0,
        };

    test('orden_items: traduce el repuesto_id antiguo', () {
      final r = RescateSincronizacionService.normalizarFila(
          'orden_items', item(repuestoId: ReglasOrden.idManoObraAnterior));
      expect(r['repuesto_id'], ReglasOrden.idManoObra);
    });

    test('inventario_repuestos: traduce el propio id antiguo', () {
      // Sin esto, el repuesto ficticio viejo parece ausente de la nube aunque
      // ya esté allí con su UUID, y se reintenta en cada subida.
      final r = RescateSincronizacionService.normalizarFila(
        'inventario_repuestos',
        {'id': ReglasOrden.idManoObraAnterior, 'nombre': 'Mano de Obra'},
      );
      expect(r['id'], ReglasOrden.idManoObra);
    });

    test('conserva el resto de columnas', () {
      final r = RescateSincronizacionService.normalizarFila(
          'orden_items', item(repuestoId: ReglasOrden.idManoObraAnterior));
      expect(r['orden_id'], uuidOrden);
      expect(r['descripcion'], 'Cambio de aceite');
      expect(r['cantidad'], 1);
      expect(r['precio_unitario'], 45000.0);
    });

    test('no modifica el mapa original que viene de SQLite', () {
      final original = item(repuestoId: ReglasOrden.idManoObraAnterior);
      RescateSincronizacionService.normalizarFila('orden_items', original);
      expect(original['repuesto_id'], ReglasOrden.idManoObraAnterior);
    });

    test('una tabla sin traducciones se devuelve tal cual', () {
      const fila = {'id': 'x', 'nombre': 'Luis'};
      expect(RescateSincronizacionService.normalizarFila('clientes', fila),
          same(fila));
    });
  });

  group('filas que la nube nunca podrá aceptar', () {
    // Las columnas id y *_id son de tipo uuid en Supabase. Los datos de
    // demostración que la app siembra al instalarse traen 'c1-uuid', 'o1-uuid'
    // y similares: Postgres los rechaza con 22P02 por muchas veces que se
    // reintente. Detectarlo evita ocho errores crípticos y una alarma perpetua.
    const uuid = '33333333-3333-4333-8333-333333333333';

    test('acepta una fila con todos los ids en formato UUID', () {
      expect(
        RescateSincronizacionService.sePuedeSubir(
            {'id': uuid, 'cliente_id': uuid, 'nombre': 'Luis'}),
        isTrue,
      );
    });

    test('rechaza el id de demostración c1-uuid', () {
      expect(
        RescateSincronizacionService.sePuedeSubir(
            {'id': 'c1-uuid', 'nombre': 'Cliente de ejemplo'}),
        isFalse,
      );
    });

    test('rechaza una referencia de demostración aunque el id sea válido', () {
      expect(
        RescateSincronizacionService.sePuedeSubir(
            {'id': uuid, 'cliente_id': 'c1-uuid'}),
        isFalse,
      );
    });

    test('rechaza el repuesto ficticio con el identificador antiguo', () {
      expect(
        RescateSincronizacionService.sePuedeSubir(
            {'id': ReglasOrden.idManoObraAnterior}),
        isFalse,
      );
    });

    test('un id nulo no descalifica la fila (taller_id opcional)', () {
      expect(
        RescateSincronizacionService.sePuedeSubir(
            {'id': uuid, 'taller_id': null}),
        isTrue,
      );
    });

    test('no confunde columnas que no son identificadores', () {
      expect(
        RescateSincronizacionService.sePuedeSubir(
            {'id': uuid, 'descripcion': 'no-es-uuid', 'cantidad': 2}),
        isTrue,
      );
    });

    test('los UUID del sistema sí son válidos', () {
      expect(RescateSincronizacionService.esUuid(ReglasOrden.idManoObra),
          isTrue);
      expect(RescateSincronizacionService.esUuid(ReglasOrden.idRepuestoExterno),
          isTrue);
    });
  });

  group('qué filas quedan pendientes', () {
    final locales = <Map<String, Object?>>[
      {'id': 'a'},
      {'id': 'b'},
      {'id': 'c'},
    ];

    test('solo devuelve las que la nube no tiene', () {
      final p = RescateSincronizacionService.pendientes(locales, {'a', 'c'});
      expect(p.map((f) => f['id']), ['b']);
    });

    test('si la nube no tiene nada, están todas pendientes', () {
      expect(RescateSincronizacionService.pendientes(locales, {}).length, 3);
    });

    test('reejecutar la subida no vuelve a enviar nada', () {
      expect(
        RescateSincronizacionService.pendientes(locales, {'a', 'b', 'c'}),
        isEmpty,
      );
    });

    test('nunca se pisa una fila que la nube ya tenga', () {
      // Es lo que protege los totales de las 14 órdenes, que en la nube son
      // lo único que sobrevivió a la pérdida.
      final p = RescateSincronizacionService.pendientes(
          [
            {'id': 'orden-con-totales-buenos'}
          ],
          {'orden-con-totales-buenos'});
      expect(p, isEmpty);
    });
  });

  group('repuestos que deben existir antes de subir los ítems', () {
    test('devuelve los ids ya traducidos, sin repetir', () {
      final n = RescateSincronizacionService.repuestosNecesarios([
        {'repuesto_id': ReglasOrden.idManoObraAnterior},
        {'repuesto_id': ReglasOrden.idManoObra},
        {'repuesto_id': ReglasOrden.idRepuestoExternoAnterior},
      ]);
      expect(n, {ReglasOrden.idManoObra, ReglasOrden.idRepuestoExterno});
    });
  });

  group('orden de subida', () {
    test('las dependencias van antes que quien las referencia', () {
      final orden = RescateSincronizacionService.tablasSincronizables
          .map((t) => t.tabla)
          .toList();
      // Un ítem no puede subir antes que su orden, ni una orden antes que su
      // cliente: la llave foránea lo rechazaría.
      expect(orden.indexOf('clientes'), lessThan(orden.indexOf('vehiculos')));
      expect(orden.indexOf('vehiculos'),
          lessThan(orden.indexOf('ordenes_mantenimiento')));
      expect(orden.indexOf('inventario_repuestos'),
          lessThan(orden.indexOf('orden_items')));
      expect(orden.indexOf('ordenes_mantenimiento'),
          lessThan(orden.indexOf('orden_items')));
      expect(orden.indexOf('ordenes_mantenimiento'),
          lessThan(orden.indexOf('orden_abonos')));
    });

    test('cubre las tablas donde se perdieron datos', () {
      final tablas = RescateSincronizacionService.tablasSincronizables
          .map((t) => t.tabla)
          .toSet();
      expect(
        tablas,
        containsAll([
          'clientes', // dejaron de subir el 30/07/2026 (campos DIAN)
          'ordenes_mantenimiento',
          'orden_items', // nunca subió ni uno
          'orden_abonos', // la tabla ni existía en la nube
        ]),
      );
    });
  });

  group('lectura del resultado', () {
    ConteoTabla conteo(String t,
            {int local = 0, int nube = 0, int faltantes = 0, int omitidas = 0}) =>
        ConteoTabla(
            tabla: t,
            etiqueta: t,
            local: local,
            nube: nube,
            faltantes: faltantes,
            omitidas: omitidas);

    test('sin fallos y sin faltantes, está completo', () {
      final r = ResultadoRescate(ejecutado: true, tablas: [
        conteo('orden_items', local: 137, nube: 137),
        conteo('orden_abonos', local: 12, nube: 12),
      ]);
      expect(r.completo, isTrue);
      expect(r.totalPendientes, 0);
    });

    test('lo pendiente se cuenta por id, no restando totales', () {
      // El caso que destapó el bug: 4 filas locales y 14 en la nube daban
      // «0 pendientes» por resta, aunque 2 de esas 4 no estuvieran arriba.
      final r = ResultadoRescate(
          tablas: [conteo('clientes', local: 4, nube: 14, faltantes: 2)]);
      expect(r.totalPendientes, 2);
    });

    test('la nube con más filas que el teléfono no es una pérdida', () {
      final r = ResultadoRescate(tablas: [conteo('clientes', local: 5, nube: 9)]);
      expect(r.totalPendientes, 0);
      expect(r.completo, isTrue);
    });

    test('un fallo impide darlo por bueno aunque no falte nada', () {
      final r = ResultadoRescate(
        ejecutado: true,
        tablas: [conteo('orden_items', local: 10, nube: 10)],
        fallos: const ['orden_items fila x: violación de llave foránea'],
      );
      expect(r.completo, isFalse);
    });

    test('las filas de demostración no cuentan como pendientes', () {
      // Si contaran, el aviso de «cambios sin subir» no se apagaría nunca,
      // porque esas filas no pueden subir por definición.
      final r = ResultadoRescate(
          ejecutado: true,
          tablas: [conteo('clientes', local: 4, nube: 14, omitidas: 2)]);
      expect(r.totalPendientes, 0);
      expect(r.totalOmitidas, 2);
      expect(r.completo, isTrue);
    });

    test('solo se listan las tablas con algo pendiente', () {
      final r = ResultadoRescate(tablas: [
        conteo('clientes', local: 5, nube: 5),
        conteo('orden_items', local: 137, nube: 0, faltantes: 137),
      ]);
      expect(r.conPendientes.map((t) => t.tabla), ['orden_items']);
    });
  });
}

/// Filas que pertenecen a otra cuenta. Añadido tras ver 16 errores `42501` en
/// un teléfono que se había usado con dos sesiones distintas.
void _pruebasDeOtraCuenta() {
  const miTaller = 'a3275146-f8b2-4514-9e05-959b98947358';
  const otroTaller = '7e031958-6a59-440e-ab88-2a163a64e38a';

  group('filas de otra cuenta', () {
    test('una fila de mi taller sí es mía', () {
      expect(
        RescateSincronizacionService.esDelTaller(
            {'id': 'x', 'taller_id': miTaller}, miTaller),
        isTrue,
      );
    });

    test('una fila de otro taller no lo es', () {
      // La nube la rechaza con 42501. No es un fallo: es el aislamiento.
      expect(
        RescateSincronizacionService.esDelTaller(
            {'id': 'x', 'taller_id': otroTaller}, miTaller),
        isFalse,
      );
    });

    test('sin taller_id se considera propia: la subida lo rellena', () {
      expect(
        RescateSincronizacionService.esDelTaller(
            {'id': 'x', 'taller_id': null}, miTaller),
        isTrue,
      );
    });

    test('una tabla sin columna taller_id no se descarta', () {
      // orden_items y orden_abonos llegan al taller por su orden.
      expect(
        RescateSincronizacionService.esDelTaller(
            {'id': 'x', 'orden_id': 'o1'}, miTaller),
        isTrue,
      );
    });

    test('sin sesión establecida no se descarta nada', () {
      expect(
        RescateSincronizacionService.esDelTaller(
            {'id': 'x', 'taller_id': otroTaller}, null),
        isTrue,
      );
    });
  });

  group('lectura del resultado con filas ajenas', () {
    test('no cuentan como pendientes ni impiden dar por bueno el resultado', () {
      const r = ResultadoRescate(
        ejecutado: true,
        tablas: [
          ConteoTabla(
              tabla: 'clientes',
              etiqueta: 'Clientes',
              local: 4,
              nube: 4,
              deOtraCuenta: 2),
        ],
      );
      expect(r.totalPendientes, 0);
      expect(r.totalDeOtraCuenta, 2);
      expect(r.completo, isTrue);
    });
  });
}

/// Los ítems y abonos no llevan `taller_id`: pertenecen al taller de su orden.
void _pruebasDeOrdenPropia() {
  group('filas que cuelgan de una orden', () {
    const propias = {'orden-mia-1', 'orden-mia-2'};

    test('un ítem de una orden mía sí se sube', () {
      expect(
        RescateSincronizacionService.esDeOrdenPropia(
            {'id': 'i1', 'orden_id': 'orden-mia-1'}, propias),
        isTrue,
      );
    });

    test('un ítem de una orden ajena no', () {
      // Sin esto se reintentaba en cada subida, fallaba con 42501 y dejaba un
      // «3 cambios sin subir» que no se apagaba nunca.
      expect(
        RescateSincronizacionService.esDeOrdenPropia(
            {'id': 'i2', 'orden_id': 'orden-de-otro'}, propias),
        isFalse,
      );
    });

    test('un ítem huérfano tampoco', () {
      expect(
        RescateSincronizacionService.esDeOrdenPropia(
            {'id': 'i3', 'orden_id': null}, propias),
        isFalse,
      );
    });
  });
}
