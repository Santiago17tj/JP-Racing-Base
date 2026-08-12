import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guarda permanente contra la familia de bugs más cara del proyecto.
///
/// En web no existe SQLite: `await database` lanza `UnsupportedError` y mata el
/// método **antes** de llegar a la rama de Supabase. Aparecieron 7 casos.
///
/// Antes esto se vigilaba con un script de Python que había que acordarse de
/// correr a mano. Peor: ese script solo miraba métodos con guardas mal
/// colocadas, así que se saltaba los que no tenían **ninguna** — que están
/// igual de rotos. Así se escapó `obtenerAbonosDeOrden` durante meses.
///
/// Ahora es una prueba: `flutter test` falla si alguien reintroduce el patrón.
void main() {
  _pruebasDeCalculosDeDinero();

  const rutaFuente = 'lib/data/database/database_helper.dart';

  /// Marcas que indican que el método comprobó el entorno antes de tocar
  /// SQLite.
  const guardas = ['kIsWeb', '_useCloud', 'SupabaseService.isConfigured'];

  /// Métodos que legítimamente solo existen en móvil y nunca se llaman desde
  /// web. Añadir aquí exige justificarlo por escrito.
  const exentos = <String>{
    '_initDB', // lo llama el getter `database`, que ya comprueba kIsWeb
  };

  late List<({String nombre, String cuerpo})> metodos;

  setUpAll(() {
    final fuente = File(rutaFuente).readAsStringSync();

    // Corta el archivo por firmas de método de primer nivel.
    final separador = RegExp(
      r'\n  (?=(?:Future|void|List|Map|String|bool|double|int)[\w<>?, ]* [_a-zA-Z]\w*\()',
    );
    final nombre = RegExp(r'[\w<>?, ]* ([_a-zA-Z]\w*)\(');

    metodos = [
      for (final trozo in fuente.split(separador))
        if (nombre.matchAsPrefix(trozo) case final m?)
          (nombre: m.group(1)!, cuerpo: trozo),
    ];
  });

  test('el archivo se pudo trocear en métodos', () {
    // Si el troceo se rompe, las pruebas de abajo pasarían vacías y darían una
    // falsa sensación de seguridad.
    expect(metodos.length, greaterThan(50),
        reason: 'La expresión que separa métodos dejó de funcionar: revísala '
            'antes de fiarte del resto de este archivo.');
    expect(metodos.map((m) => m.nombre), contains('getItemsDeOrden'));
    expect(metodos.map((m) => m.nombre), contains('obtenerAbonosDeOrden'));
  });

  test('ningún método abre SQLite antes de comprobar el entorno', () {
    final rotos = <String>[];

    for (final m in metodos) {
      if (exentos.contains(m.nombre)) continue;

      final posicionDb = m.cuerpo.indexOf('await database');
      if (posicionDb == -1) continue;

      final posiciones = [
        for (final g in guardas)
          if (m.cuerpo.indexOf(g) != -1) m.cuerpo.indexOf(g)
      ];
      if (posiciones.isEmpty) continue; // lo cubre la prueba siguiente
      if (posicionDb < posiciones.reduce((a, b) => a < b ? a : b)) {
        rotos.add(m.nombre);
      }
    }

    expect(rotos, isEmpty,
        reason: 'Estos métodos abren SQLite antes de comprobar el entorno, así '
            'que en web lanzan y nunca llegan a la rama de la nube: $rotos');
  });

  test('ningún método abre SQLite sin ninguna comprobación de entorno', () {
    final sinGuarda = <String>[];

    for (final m in metodos) {
      if (exentos.contains(m.nombre)) continue;
      if (!m.cuerpo.contains('await database')) continue;
      if (guardas.any(m.cuerpo.contains)) continue;
      sinGuarda.add(m.nombre);
    }

    expect(sinGuarda, isEmpty,
        reason: 'Estos métodos abren SQLite sin comprobar el entorno. En web '
            'revientan enteros. Es el caso que el script anterior no veía y por '
            'el que `obtenerAbonosDeOrden` estuvo roto meses: $sinGuarda');
  });

  test('debugPrint no es la única señal de un fallo de sincronización', () {
    final fuente = File(rutaFuente).readAsStringSync();

    // No se puede prohibir debugPrint —está bien para diagnóstico—, pero sí
    // exigir que exista un camino que no dependa de él. Ese camino es
    // `prepararParaNube`, que usa el servicio de rescate para comparar el
    // teléfono contra la nube y sacar los pendientes a la pantalla.
    expect(fuente.contains('Map<String, dynamic> prepararParaNube('), isTrue,
        reason: 'El servicio de sincronización pendiente depende de este '
            'método: sin él, un fallo vuelve a ser invisible en release.');
  });
}

/// Ningún cálculo de dinero fuera de `ReglasOrden`.
///
/// El 12/08/2026 aparecieron **cuatro** sitios en `database_helper` que
/// recalculaban el subtotal de la orden a mano con `cantidad * precio`,
/// ignorando el descuento — mientras la línea del ítem sí lo aplicaba. Un
/// repuesto rebajado se cobraba de más y la factura se contradecía a sí misma.
///
/// Se escaparon a la vista porque cada uno usaba nombres de variable distintos
/// (`cantidad`/`cant`, `precio`). Esta prueba busca el patrón, no los nombres.
void _pruebasDeCalculosDeDinero() {
  test('el subtotal solo se calcula en ReglasOrden', () {
    const fuentes = [
      'lib/data/database/database_helper.dart',
      'lib/ui/screens/detalle_orden_screen.dart',
      'lib/core/services/pdf_factura_service.dart',
      'lib/core/services/factura_service.dart',
    ];

    // Multiplicar una cantidad por un precio es, por definición, calcular
    // dinero. Solo `ReglasOrden` y el propio `OrdenItem` pueden hacerlo.
    final patron = RegExp(
      r'(cant\w*|unidades)\s*\*\s*(precio\w*)|(precio\w*)\s*\*\s*(cant\w*)',
      caseSensitive: false,
    );

    final infractores = <String>[];
    for (final ruta in fuentes) {
      final archivo = File(ruta);
      if (!archivo.existsSync()) continue;
      final lineas = archivo.readAsLinesSync();
      for (var i = 0; i < lineas.length; i++) {
        if (patron.hasMatch(lineas[i])) {
          infractores.add('$ruta:${i + 1}  ${lineas[i].trim()}');
        }
      }
    }

    expect(infractores, isEmpty,
        reason: 'Estas líneas calculan dinero fuera de ReglasOrden. Usa '
            'ReglasOrden.subtotalRepuestosCrudo, que excluye la mano de obra y '
            'aplica el descuento:\n${infractores.join('\n')}');
  });
}
