/// Traduce los errores técnicos a algo que un mecánico pueda leer.
///
/// La app ya no esconde sus fallos —ese fue el bug de fondo del proyecto— pero
/// enseñarlos en crudo tampoco sirve: una caída de internet aparecía como
/// quinientos caracteres de excepción y URL con catorce UUID dentro. Quien lo
/// lee no sabe si perdió datos o si solo se le fue la señal.
///
/// La regla: decir qué pasó y si hay algo que hacer. El detalle técnico se
/// conserva recortado, porque cuando algo raro ocurre hay que poder verlo.
class MensajesError {
  const MensajesError._();

  /// Largo máximo del detalle técnico que se muestra cuando no se reconoce
  /// el error. Suficiente para identificarlo, no para llenar la pantalla.
  static const int _maximo = 160;

  /// Mensaje legible para [error].
  static String legible(Object? error) {
    final texto = error?.toString() ?? '';
    if (texto.isEmpty) return 'Error desconocido.';

    final minusculas = texto.toLowerCase();

    // Sin internet. Es con diferencia el caso más común y el más inofensivo:
    // los datos siguen en el teléfono y suben solos cuando vuelva la señal.
    if (minusculas.contains('socketexception') ||
        minusculas.contains('failed host lookup') ||
        minusculas.contains('clientexception') ||
        minusculas.contains('connection closed') ||
        minusculas.contains('connection refused') ||
        minusculas.contains('network is unreachable')) {
      return 'Sin conexión a internet. Los datos están guardados en el '
          'teléfono y se suben solos cuando vuelva la señal.';
    }

    if (minusculas.contains('timeoutexception') ||
        minusculas.contains('timed out')) {
      return 'La conexión tardó demasiado. Vuelve a intentarlo con mejor '
          'señal.';
    }

    // Aislamiento entre talleres. No es un fallo: es la nube protegiendo los
    // datos de cada cuenta.
    if (texto.contains('42501') ||
        minusculas.contains('row-level security')) {
      return 'Ese dato pertenece a otra cuenta, así que no se sube. No se '
          'pierde nada: está guardado en la cuenta a la que pertenece.';
    }

    // Identificadores que no son UUID: datos de ejemplo o de versiones viejas.
    if (texto.contains('22P02') ||
        minusculas.contains('invalid input syntax for type uuid')) {
      return 'Fila con un identificador antiguo que la nube no admite. Suele '
          'ser un dato de ejemplo; no es información del taller.';
    }

    // Columna que existe en un lado y no en el otro.
    if (minusculas.contains('no such column') ||
        texto.contains('PGRST204') ||
        minusculas.contains('could not find') && minusculas.contains('column')) {
      return 'La app y la nube no coinciden en un campo. Avisa a quien '
          'mantiene la app: hay que actualizarla.';
    }

    if (minusculas.contains('duplicate key') || texto.contains('23505')) {
      return 'Ya existe un registro con ese identificador.';
    }

    if (minusculas.contains('foreign key') || texto.contains('23503')) {
      return 'Falta el dato del que depende este (su cliente, su moto o su '
          'orden). Debería resolverse al volver a sincronizar.';
    }

    if (minusculas.contains('jwt') ||
        minusculas.contains('not authenticated') ||
        texto.contains('401')) {
      return 'La sesión caducó. Cierra sesión y vuelve a entrar.';
    }

    return recortar(texto);
  }

  /// Recorta un texto largo dejando el principio, que es donde está la causa.
  ///
  /// Las excepciones de red traen la URL completa al final, con un
  /// identificador por cada fila consultada: cientos de caracteres que no
  /// aportan nada.
  static String recortar(String texto, {int maximo = _maximo}) {
    final limpio = texto.trim();
    if (limpio.length <= maximo) return limpio;
    return '${limpio.substring(0, maximo).trimRight()}…';
  }
}
