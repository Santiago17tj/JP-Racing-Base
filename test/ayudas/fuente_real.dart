import 'dart:io';

import 'package:flutter/services.dart';

/// Carga una fuente **de verdad** en el entorno de pruebas.
///
/// Por defecto `flutter test` dibuja cada carácter como un cuadrado del alto de
/// la letra. Es mucho más ancha que cualquier tipografía real —«REGISTRAR VENTA
/// (PAGADA)» mide 374 px con ella y 199 con Roboto—, así que **con la fuente
/// por defecto no se puede medir nada**: desbordan cajas que en el teléfono
/// caben de sobra, y podrían no desbordar cajas que sí se recortan.
///
/// Roboto viene con el SDK de Flutter, así que no hay que meter un binario en
/// el repositorio ni depender de la red. `flutter test` exporta `FLUTTER_ROOT`,
/// que es de donde sale la ruta.
///
/// Uso:
/// ```dart
/// setUpAll(cargarRoboto);
/// testWidgets('...', (tester) async { ... }, skip: motivoParaSaltar());
/// ```
/// El `skip` tiene que resolverse **sin `await`**: las pruebas se registran de
/// forma síncrona, y por eso la comprobación (`_archivoRoboto`) mira el disco
/// mientras que la carga en sí, que sí es asíncrona, va en `setUpAll`.

/// Ruta de Roboto en el SDK, o `null` si no está donde se espera.
File? _archivoRoboto() {
  final raiz = Platform.environment['FLUTTER_ROOT'];
  if (raiz == null || raiz.isEmpty) return null;

  final directorio = Directory('$raiz/bin/cache/artifacts/material_fonts');
  if (!directorio.existsSync()) return null;

  // El nombre del archivo ha cambiado de mayúsculas entre versiones del SDK.
  return directorio
      .listSync()
      .whereType<File>()
      .where((f) => f.path.toLowerCase().endsWith('roboto-regular.ttf'))
      .firstOrNull;
}

/// ¿Hay que saltarse las pruebas de disposición?
///
/// Se pasa al parámetro `skip` de `testWidgets`, que solo acepta un booleano.
/// El porqué lo imprime [cargarRoboto], para que no se salten en silencio.
bool sinFuenteReal() => _archivoRoboto() == null;

/// Registra Roboto como familia «Roboto». Llamar desde `setUpAll`.
Future<void> cargarRoboto() async {
  final archivo = _archivoRoboto();
  if (archivo == null) {
    // ignore: avoid_print
    print(
      'AVISO: no se encontró Roboto en el SDK de Flutter (FLUTTER_ROOT), así '
      'que las pruebas de disposición se saltan. Medir con la fuente de prueba '
      'no significa nada. Si una versión del SDK movió la carpeta, arregla la '
      'ruta en test/ayudas/fuente_real.dart en vez de borrar las pruebas.',
    );
    return;
  }

  final cargador = FontLoader('Roboto')
    ..addFont(Future.value(archivo.readAsBytesSync().buffer.asByteData()));
  await cargador.load();
}
