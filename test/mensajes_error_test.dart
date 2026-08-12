import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/core/dominio/mensajes_error.dart';

/// La app dejó de esconder sus fallos, pero enseñarlos en crudo tampoco sirve.
///
/// El caso real que motivó esto: una caída de internet salía en pantalla como
/// medio kilo de excepción con la URL entera y catorce UUID dentro. El mecánico
/// que lo lee no sabe si perdió su trabajo o si solo se le fue la señal.
void main() {
  group('sin conexión', () {
    // Es el error más común y el más inofensivo: nada se pierde.
    const real =
        "ClientException with SocketException: Failed host lookup: "
        "'snzqauzmtydcheryfwmd.supabase.co' (OS Error: No address associated "
        "with hostname, errno = 7), uri=https://snzqauzmtydcheryfwmd.supabase."
        "co/rest/v1/orden_items?select=%2A&orden_id=in.%28%223455e12c-a9a4-"
        "4b30-bb39-1e2ab7f35e76%22%2C%2229adf477f-c1fd-43ef-b3aa-4a1db658c584";

    test('se traduce a algo que se entiende', () {
      final m = MensajesError.legible(real);
      expect(m, contains('Sin conexión'));
      expect(m, contains('se suben solos'));
    });

    test('no arrastra la URL ni los identificadores', () {
      final m = MensajesError.legible(real);
      expect(m, isNot(contains('http')));
      expect(m, isNot(contains('uri=')));
      expect(m, isNot(contains('3455e12c')));
    });

    test('cabe en una pantalla', () {
      expect(MensajesError.legible(real).length, lessThan(160));
    });
  });

  group('errores de la nube que tienen explicación', () {
    test('42501 se explica como aislamiento entre cuentas, no como pérdida',
        () {
      final m = MensajesError.legible(
          'PostgrestException(message: new row violates row-level security '
          'policy for table "clientes", code: 42501)');
      expect(m, contains('otra cuenta'));
      expect(m, contains('No se pierde nada'));
    });

    test('22P02 apunta a los datos de ejemplo', () {
      final m = MensajesError.legible(
          'PostgrestException(message: invalid input syntax for type uuid: '
          '"c1-uuid", code: 22P02)');
      expect(m, contains('identificador antiguo'));
    });

    test('una columna que falta pide actualizar la app', () {
      final m = MensajesError.legible(
          'DatabaseException(no such column: monto_pagado (code 1 SQLITE_ERROR))');
      expect(m, contains('no coinciden'));
      expect(m, contains('actualizarla'));
    });

    test('la sesión caducada dice qué hacer', () {
      final m = MensajesError.legible('JWT expired');
      expect(m, contains('sesión'));
      expect(m, contains('vuelve a entrar'));
    });

    test('una llave foránea no alarma: se resuelve al sincronizar', () {
      final m = MensajesError.legible(
          'insert or update violates foreign key constraint, code: 23503');
      expect(m, contains('sincronizar'));
    });
  });

  group('lo que no se reconoce', () {
    test('se muestra recortado, no entero', () {
      final largo = 'ErrorRarísimo: ${'x' * 500}';
      final m = MensajesError.legible(largo);
      expect(m.length, lessThan(180));
      expect(m, endsWith('…'));
      // Pero se conserva el principio, que es donde está la causa.
      expect(m, startsWith('ErrorRarísimo'));
    });

    test('un error corto se deja tal cual', () {
      expect(MensajesError.legible('Algo raro pasó'), 'Algo raro pasó');
    });

    test('nulo o vacío no revientan', () {
      expect(MensajesError.legible(null), 'Error desconocido.');
      expect(MensajesError.legible(''), 'Error desconocido.');
    });
  });
}
