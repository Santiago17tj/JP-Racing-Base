import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/data/database/database_helper.dart';
import 'package:moto_taller_app/data/database/fuente_de_datos.dart';

/// La inyección de `FuenteDeDatos` solo sirve mientras nadie la rodee.
///
/// El compilador ya obliga a que `_db` sea una `FuenteDeDatos`, pero no impide
/// que un provider escriba `DatabaseHelper.instance.loQueSea()` en medio de un
/// método: eso volvería a atar esa pantalla a SQLite y sus pruebas dejarían de
/// poder sustituir la base sin avisar de nada.
void main() {
  final directorio = Directory('lib/data/providers');

  test('DatabaseHelper sigue implementando FuenteDeDatos', () {
    expect(DatabaseHelper.instance, isA<FuenteDeDatos>());
  });

  test('ningún provider llama a la base real por su cuenta', () {
    final archivos = directorio
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    // Si el listado se rompe, la prueba pasaría vacía y daría falsa seguridad.
    expect(archivos, isNotEmpty, reason: 'no se encontró ningún provider');

    final infractores = <String>[];
    for (final archivo in archivos) {
      final contenido = archivo.readAsStringSync();
      expect(contenido, isNotEmpty, reason: '${archivo.path} se leyó vacío');

      for (final linea in contenido.split('\n')) {
        // `DatabaseHelper.activeTallerId` es un campo estático de configuración,
        // no una consulta: se permite. Lo que no puede aparecer es el singleton
        // resolviendo datos a espaldas de la interfaz.
        if (linea.contains('DatabaseHelper.instance.')) {
          infractores.add('${archivo.uri.pathSegments.last}: ${linea.trim()}');
        }
      }
    }

    expect(
      infractores,
      isEmpty,
      reason: 'Estos providers se saltan FuenteDeDatos y no se podrán probar '
          'con una base falsa:\n${infractores.join('\n')}\n'
          'Usa el campo `_db` que reciben por constructor.',
    );
  });

  test('la comprobación anterior detecta de verdad una llamada directa', () {
    // Verifica el detector, no el código: si la expresión dejara de encontrar
    // nada, la prueba de arriba pasaría siempre.
    const lineaMala = 'await DatabaseHelper.instance.getClientes();';
    const lineaBuena = 'DatabaseHelper.activeTallerId = taller?.id;';
    expect(lineaMala.contains('DatabaseHelper.instance.'), isTrue);
    expect(lineaBuena.contains('DatabaseHelper.instance.'), isFalse);
  });
}
