import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../../data/database/database_helper.dart';
import '../dominio/mensajes_error.dart';
import '../dominio/reglas_orden.dart';
import 'supabase_service.dart';

/// Una tabla y cuánto tiene el teléfono frente a la nube.
@immutable
class ConteoTabla {
  /// Nombre de la tabla en Supabase.
  final String tabla;

  /// Cómo llamarla delante del usuario.
  final String etiqueta;

  final int local;
  final int nube;

  /// Filas del teléfono que la nube no tiene **y que sí se pueden subir**.
  ///
  /// Se cuenta comparando `id` uno a uno, no restando totales. Restar mentía:
  /// con 4 filas locales y 14 en la nube daba «0 pendientes» aunque 2 de esas
  /// 4 no estuvieran arriba.
  final int faltantes;

  /// Filas que la nube no tiene y que **nunca** podrá aceptar, porque su `id`
  /// (o el de algo que referencian) no es un UUID: los datos de demostración
  /// que la app siembra al instalarse y los repuestos ficticios con el
  /// identificador antiguo. No son un error ni una pérdida: son basura local.
  final int omitidas;

  /// Filas que pertenecen a **otro taller**.
  ///
  /// Pasa cuando el mismo teléfono se usó con dos cuentas distintas: quedan en
  /// SQLite datos del taller anterior. La nube los rechaza con `42501` y hace
  /// bien — una cuenta no puede subir datos de otra. No es un error a corregir,
  /// es el aislamiento funcionando.
  final int deOtraCuenta;

  /// Filas aceptadas por Supabase en esta ejecución.
  final int subidas;

  const ConteoTabla({
    required this.tabla,
    required this.etiqueta,
    this.local = 0,
    this.nube = 0,
    this.faltantes = 0,
    this.omitidas = 0,
    this.deOtraCuenta = 0,
    this.subidas = 0,
  });

  ConteoTabla copyWith({
    int? local,
    int? nube,
    int? faltantes,
    int? omitidas,
    int? deOtraCuenta,
    int? subidas,
  }) =>
      ConteoTabla(
        tabla: tabla,
        etiqueta: etiqueta,
        local: local ?? this.local,
        nube: nube ?? this.nube,
        faltantes: faltantes ?? this.faltantes,
        omitidas: omitidas ?? this.omitidas,
        deOtraCuenta: deOtraCuenta ?? this.deOtraCuenta,
        subidas: subidas ?? this.subidas,
      );
}

/// Resultado de un diagnóstico o de una subida.
///
/// Todo lo que falla queda en [fallos] con el mensaje real del servidor. Esta
/// clase existe precisamente porque el patrón anterior —`catch` con
/// `debugPrint`, anulado en release— hacía invisible cualquier error.
@immutable
class ResultadoRescate {
  final List<ConteoTabla> tablas;

  /// Repuestos que hubo que crear en la nube para no violar la llave foránea.
  final int repuestosCreados;

  /// Órdenes cuyo estado de pago se copió del teléfono a la nube.
  final int pagosActualizados;

  /// Errores con su causa textual. Si esto no está vacío, quedó trabajo sin
  /// hacer por más que los contadores se vean bien.
  final List<String> fallos;

  /// `false` cuando solo se diagnosticó, sin escribir nada.
  final bool ejecutado;

  const ResultadoRescate({
    this.tablas = const [],
    this.repuestosCreados = 0,
    this.pagosActualizados = 0,
    this.fallos = const [],
    this.ejecutado = false,
  });

  /// Filas subibles que la nube todavía no tiene. Es lo que alimenta el aviso
  /// de «N cambios sin subir».
  int get totalPendientes =>
      tablas.fold<int>(0, (suma, t) => suma + t.faltantes);

  /// Filas locales que la nube nunca podrá aceptar (demo y restos antiguos).
  /// Se informan aparte para que no disparen una alarma que jamás se apaga.
  int get totalOmitidas =>
      tablas.fold<int>(0, (suma, t) => suma + t.omitidas);

  /// Filas que quedaron de otra sesión en el mismo teléfono.
  int get totalDeOtraCuenta =>
      tablas.fold<int>(0, (suma, t) => suma + t.deOtraCuenta);

  /// Solo las tablas con algo pendiente, para no llenar la pantalla de ceros.
  List<ConteoTabla> get conPendientes =>
      tablas.where((t) => t.faltantes > 0).toList();

  /// La nube tiene todo lo subible y nada falló por el camino.
  bool get completo => fallos.isEmpty && totalPendientes == 0;
}

/// Sube a Supabase lo que quedó atrapado únicamente en el SQLite del teléfono.
///
/// Contexto: durante meses el patrón «intento la nube, si falla uso local» se
/// tragó todos los errores. No llegó ni un `orden_items`, ni un abono, y desde
/// el 30/07/2026 tampoco los clientes nuevos (el modelo ganó los campos de la
/// DIAN y la nube no tenía esas columnas).
///
/// El diagnóstico **mide la realidad** en vez de fiarse de que cada `catch`
/// haya registrado su fallo: compara filas del teléfono contra filas de la
/// nube. Un error que nadie anotó igual aparece como diferencia.
///
/// Corre **solo en el móvil**: es donde está el SQLite.
class RescateSincronizacionService {
  const RescateSincronizacionService();

  /// Filas por petición al comparar o subir en bloque.
  static const int _tamanoLote = 50;

  /// Tablas a sincronizar, **en orden de dependencia**: una orden no puede
  /// subir antes que su cliente, ni un ítem antes que su orden.
  static const List<({String tabla, String etiqueta, bool tieneTaller})>
      tablasSincronizables = [
    (tabla: 'clientes', etiqueta: 'Clientes', tieneTaller: true),
    (tabla: 'vehiculos', etiqueta: 'Motos', tieneTaller: true),
    (
      tabla: 'inventario_repuestos',
      etiqueta: 'Repuestos del inventario',
      tieneTaller: true
    ),
    (
      tabla: 'ordenes_mantenimiento',
      etiqueta: 'Órdenes de trabajo',
      tieneTaller: true
    ),
    (
      tabla: 'orden_items',
      etiqueta: 'Repuestos usados en órdenes',
      tieneTaller: false
    ),
    (tabla: 'orden_abonos', etiqueta: 'Abonos de clientes', tieneTaller: false),
    (
      tabla: 'registro_caja',
      etiqueta: 'Movimientos de caja',
      tieneTaller: true
    ),
  ];

  // ──────────────────────────────────────────────
  //  Lógica pura (sin base de datos, con pruebas)
  // ──────────────────────────────────────────────

  /// Traduce los identificadores antiguos a los UUID que la nube exige.
  ///
  /// Los ítems guardados antes del cambio llevan `'item-mano-obra'` /
  /// `'item-externo-generico'`, que no son UUID: Supabase los rechaza al
  /// validar el tipo y la llave foránea.
  static String repuestoIdParaNube(Object? repuestoId) {
    if (repuestoId == ReglasOrden.idManoObraAnterior) {
      return ReglasOrden.idManoObra;
    }
    if (repuestoId == ReglasOrden.idRepuestoExternoAnterior) {
      return ReglasOrden.idRepuestoExterno;
    }
    return repuestoId as String;
  }

  static final RegExp _formatoUuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Quita los dos repuestos ficticios del sistema de un recuento.
  ///
  /// No pertenecen a ningún taller (su `taller_id` es nulo) y por eso no se
  /// descargan como inventario. Contarlos solo del lado de la nube hacía que la
  /// pantalla mostrara «2 aquí · 4 en la nube» sin que faltara nada.
  static Iterable<T> sinRepuestosDelSistema<T>(
          Iterable<T> filas, String Function(T) id) =>
      filas.where((f) => !ReglasOrden.especiales.containsKey(id(f)));

  /// ¿Este valor sirve como UUID para Postgres?
  static bool esUuid(Object? valor) =>
      valor is String && _formatoUuid.hasMatch(valor);

  /// Traduce los identificadores antiguos de una fila **antes** de compararla
  /// con la nube.
  ///
  /// En `inventario_repuestos` el propio `id` puede ser `'item-mano-obra'`, y
  /// en `orden_items` lo es `repuesto_id`. Si no se traducen antes, la fila
  /// parece ausente de la nube cuando en realidad ya está allí con su UUID.
  static Map<String, Object?> normalizarFila(
      String tabla, Map<String, Object?> fila) {
    if (tabla == 'inventario_repuestos' && ReglasOrden.esEspecial(fila['id'])) {
      return {...fila, 'id': repuestoIdParaNube(fila['id'])};
    }
    if (tabla == 'orden_items') {
      return {...fila, 'repuesto_id': repuestoIdParaNube(fila['repuesto_id'])};
    }
    return fila;
  }

  /// ¿La nube puede aceptar esta fila?
  ///
  /// Toda columna `id` o `*_id` es de tipo `uuid` en Supabase. Si alguna trae
  /// algo que no lo es, Postgres rechaza la fila con `22P02` por más veces que
  /// se reintente. Le pasa a los datos de demostración que la app siembra al
  /// instalarse (`c1-uuid`, `o1-uuid`…) y a los repuestos ficticios antiguos.
  ///
  /// Detectarlo aquí evita dos cosas: ocho errores crípticos en pantalla, y un
  /// aviso de «cambios sin subir» que no se apagaría nunca.
  /// ¿Esta fila pertenece al taller de la sesión actual?
  ///
  /// Un teléfono usado con dos cuentas guarda en SQLite filas de las dos. La
  /// nube rechaza las ajenas con `42501` y hace bien; detectarlo aquí evita
  /// una pantalla llena de errores de seguridad que asustan y no significan
  /// nada malo. `taller_id` nulo se considera propio: son filas antiguas
  /// creadas antes de que existiera el campo, y la subida se lo rellena.
  static bool esDelTaller(Map<String, Object?> fila, String? tallerActivo) {
    if (tallerActivo == null) return true;
    if (!fila.containsKey('taller_id')) return true;
    final propietario = fila['taller_id'];
    return propietario == null || propietario == tallerActivo;
  }

  /// Igual que [esDelTaller] pero para las tablas que no llevan `taller_id`.
  ///
  /// `orden_items` y `orden_abonos` llegan al taller a través de su orden, y la
  /// RLS los juzga por ahí. Sin esta comprobación, los ítems de una orden ajena
  /// se intentaban subir una y otra vez, fallaban con `42501` y dejaban un
  /// «3 cambios sin subir» que no se apagaba nunca.
  static bool esDeOrdenPropia(
          Map<String, Object?> fila, Set<String> ordenesPropias) =>
      ordenesPropias.contains(fila['orden_id']);

  static bool sePuedeSubir(Map<String, Object?> fila) {
    for (final entrada in fila.entries) {
      final esColumnaId =
          entrada.key == 'id' || entrada.key.endsWith('_id');
      if (!esColumnaId) continue;
      if (entrada.value == null) continue;
      if (!esUuid(entrada.value)) return false;
    }
    return true;
  }

  /// Filas locales que todavía no están en la nube, comparando por `id`.
  ///
  /// Se compara por id y no por contenido para que reejecutar el rescate sea
  /// inofensivo: lo ya subido no se vuelve a tocar, ni se pisan las órdenes,
  /// cuyos totales en la nube son lo único que sobrevivió.
  static List<Map<String, Object?>> pendientes(
    Iterable<Map<String, Object?>> locales,
    Set<String> idsEnNube,
  ) =>
      locales.where((f) => !idsEnNube.contains(f['id'] as String)).toList();

  /// Ids de repuesto que los ítems necesitan que existan en la nube, ya
  /// traducidos. Sin esto, la llave foránea rechaza el ítem.
  static Set<String> repuestosNecesarios(
          Iterable<Map<String, Object?>> items) =>
      items.map((f) => repuestoIdParaNube(f['repuesto_id'])).toSet();

  // ──────────────────────────────────────────────
  //  Diagnóstico (no escribe nada)
  // ──────────────────────────────────────────────

  /// Cuenta qué hay en el teléfono y qué hay en la nube, sin modificar nada.
  ///
  /// Es lo que alimenta el indicador de «cambios sin subir».
  Future<ResultadoRescate> diagnosticar() async {
    final bloqueo = _motivoParaNoCorrer();
    if (bloqueo != null) return ResultadoRescate(fallos: [bloqueo]);

    final fallos = <String>[];
    final conteos = <ConteoTabla>[];
    final db = await DatabaseHelper.instance.database;
    final ordenesPropias = await _ordenesDelTaller(db);

    for (final t in tablasSincronizables) {
      var locales = (await _filasLocales(db, t.tabla))
          .map((f) => normalizarFila(t.tabla, f))
          .toList(growable: false);
      if (t.tabla == 'inventario_repuestos') {
        locales = sinRepuestosDelSistema(locales, (f) => f['id'] as String)
            .toList(growable: false);
      }

      Set<String> enNube;
      try {
        enNube = _sinEspeciales(t.tabla, await _idsEnNube(t.tabla));
      } catch (e) {
        fallos.add('${t.etiqueta}: ${MensajesError.legible(e)}');
        conteos.add(ConteoTabla(
            tabla: t.tabla, etiqueta: t.etiqueta, local: locales.length));
        continue;
      }

      final ausentes = pendientes(locales, enNube);
      final propias = ausentes
          .where((f) => _esPropia(t.tabla, f, ordenesPropias))
          .toList(growable: false);
      final subibles = propias.where(sePuedeSubir).length;

      conteos.add(ConteoTabla(
        tabla: t.tabla,
        etiqueta: t.etiqueta,
        local: locales.length,
        nube: enNube.length,
        faltantes: subibles,
        omitidas: propias.length - subibles,
        deOtraCuenta: ausentes.length - propias.length,
      ));
    }

    return ResultadoRescate(tablas: conteos, fallos: fallos);
  }

  /// Cuántos cambios hay sin subir. Devuelve 0 si no se puede comprobar, para
  /// que el indicador nunca invente una alarma.
  Future<int> contarPendientes() async {
    try {
      return (await diagnosticar()).totalPendientes;
    } catch (_) {
      return 0;
    }
  }

  // ──────────────────────────────────────────────
  //  Subida
  // ──────────────────────────────────────────────

  /// Sube lo que solo existe en el teléfono, tabla por tabla y en orden de
  /// dependencia.
  ///
  /// Es idempotente: compara por `id` y solo envía lo que falta, así que se
  /// puede repetir sin duplicar nada y **nunca sobrescribe** una fila que la
  /// nube ya tenga.
  Future<ResultadoRescate> subirPendientes() async {
    final bloqueo = _motivoParaNoCorrer();
    if (bloqueo != null) {
      return ResultadoRescate(ejecutado: true, fallos: [bloqueo]);
    }

    final fallos = <String>[];
    final conteos = <ConteoTabla>[];
    final helper = DatabaseHelper.instance;
    final db = await helper.database;
    final ordenesPropias = await _ordenesDelTaller(db);
    var repuestosCreados = 0;

    for (final t in tablasSincronizables) {
      var locales = (await _filasLocales(db, t.tabla))
          .map((f) => normalizarFila(t.tabla, f))
          .toList(growable: false);
      if (t.tabla == 'inventario_repuestos') {
        locales = sinRepuestosDelSistema(locales, (f) => f['id'] as String)
            .toList(growable: false);
      }

      Set<String> yaEnNube;
      try {
        yaEnNube = _sinEspeciales(t.tabla, await _idsEnNube(t.tabla));
      } catch (e) {
        fallos.add('${t.etiqueta}: ${MensajesError.legible(e)}');
        conteos.add(ConteoTabla(
            tabla: t.tabla, etiqueta: t.etiqueta, local: locales.length));
        continue;
      }

      final ausentes = pendientes(locales, yaEnNube);

      // Las filas de otro taller las rechaza la RLS con 42501. No son un fallo
      // que corregir: es el aislamiento entre cuentas funcionando.
      final propias = ausentes
          .where((f) => _esPropia(t.tabla, f, ordenesPropias))
          .toList(growable: false);
      final deOtraCuenta = ausentes.length - propias.length;

      // Las filas con un id que no es UUID no las puede aceptar Postgres:
      // reintentarlas solo produce errores crípticos y una alarma que no se
      // apaga. Se cuentan aparte y no se envían.
      final porSubir = propias.where(sePuedeSubir).toList(growable: false);
      final omitidas = propias.length - porSubir.length;

      // Los repuestos que un ítem referencia deben existir antes que el ítem.
      if (t.tabla == 'orden_items' && porSubir.isNotEmpty) {
        repuestosCreados +=
            await _asegurarRepuestos(db, repuestosNecesarios(porSubir), fallos);
      }

      final preparadas = porSubir.map((fila) {
        final map = helper.prepararParaNube(Map<String, dynamic>.from(fila));
        if (t.tieneTaller && map['taller_id'] == null) {
          map['taller_id'] = DatabaseHelper.activeTallerId;
        }
        return map;
      }).toList(growable: false);

      final subidas = await _subir(t.tabla, preparadas, t.etiqueta, fallos);

      var despues = yaEnNube.length;
      var faltanAun = porSubir.length - subidas;
      try {
        final ahora = _sinEspeciales(t.tabla, await _idsEnNube(t.tabla));
        despues = ahora.length;
        faltanAun = pendientes(locales, ahora)
            .where((f) => _esPropia(t.tabla, f, ordenesPropias))
            .where(sePuedeSubir)
            .length;
      } catch (e) {
        fallos.add('${t.etiqueta}: ${MensajesError.legible(e)}');
      }

      conteos.add(ConteoTabla(
        tabla: t.tabla,
        etiqueta: t.etiqueta,
        local: locales.length,
        nube: despues,
        faltantes: faltanAun < 0 ? 0 : faltanAun,
        omitidas: omitidas,
        deOtraCuenta: deOtraCuenta,
        subidas: subidas,
      ));
    }

    // El estado de pago vive en la orden, no en una tabla propia: en la nube
    // estaba en cero porque los abonos nunca subieron.
    final pagos = await _sincronizarPagos(db, fallos);

    return ResultadoRescate(
      ejecutado: true,
      tablas: conteos,
      repuestosCreados: repuestosCreados,
      pagosActualizados: pagos,
      fallos: fallos,
    );
  }

  // ──────────────────────────────────────────────
  //  Auxiliares
  // ──────────────────────────────────────────────

  /// ¿Esta fila es de la cuenta activa? Las tablas con `taller_id` se juzgan
  /// por él; las que cuelgan de una orden, por el dueño de esa orden.
  bool _esPropia(String tabla, Map<String, Object?> fila,
          Set<String> ordenesPropias) =>
      (tabla == 'orden_items' || tabla == 'orden_abonos')
          ? esDeOrdenPropia(fila, ordenesPropias)
          : esDelTaller(fila, DatabaseHelper.activeTallerId);

  /// Ids de las órdenes locales que pertenecen al taller de la sesión.
  Future<Set<String>> _ordenesDelTaller(Database db) async {
    final activo = DatabaseHelper.activeTallerId;
    final filas = await _filasLocales(db, 'ordenes_mantenimiento');
    return {
      for (final f in filas)
        if (esDelTaller(f, activo)) f['id'] as String
    };
  }

  /// Razón por la que esto no puede correr aquí, o `null` si sí puede.
  String? _motivoParaNoCorrer() {
    if (kIsWeb) {
      return 'Esto solo corre en el teléfono: los datos pendientes están en su '
          'SQLite y en web esa base no existe.';
    }
    if (!SupabaseService.isConfigured) {
      return 'Supabase no está configurado en esta compilación.';
    }
    if (SupabaseService.client.auth.currentUser == null) {
      return 'Hay que iniciar sesión antes de subir: sin sesión, las políticas '
          'de seguridad rechazan cada fila.';
    }
    return null;
  }

  /// Lee una tabla local tolerando que no exista todavía (bases creadas con
  /// una versión anterior del esquema).
  Future<List<Map<String, Object?>>> _filasLocales(
      Database db, String tabla) async {
    try {
      return await db.query(tabla);
    } catch (_) {
      return const [];
    }
  }

  /// Igual que [sinRepuestosDelSistema] pero sobre un conjunto de ids.
  Set<String> _sinEspeciales(String tabla, Set<String> ids) =>
      tabla == 'inventario_repuestos'
          ? {...sinRepuestosDelSistema(ids, (id) => id)}
          : ids;

  /// Ids que la nube ya tiene para esa tabla. La RLS limita la respuesta al
  /// taller de la sesión, así que no hace falta filtrar aquí.
  Future<Set<String>> _idsEnNube(String tabla) async {
    final res =
        await SupabaseService.client.from(tabla).select('id').limit(20000);
    return {for (final fila in res as List) (fila as Map)['id'] as String};
  }

  /// Garantiza que cada repuesto referenciado exista en la nube.
  ///
  /// Los dos ficticios del sistema se crean con los datos de
  /// [ReglasOrden.especiales]; el resto se copia del inventario local.
  Future<int> _asegurarRepuestos(
    Database db,
    Set<String> necesarios,
    List<String> fallos,
  ) async {
    if (necesarios.isEmpty) return 0;

    Set<String> enNube;
    try {
      enNube = await _idsEnNube('inventario_repuestos');
    } catch (e) {
      fallos.add('Inventario: ${MensajesError.legible(e)}');
      return 0;
    }

    var creados = 0;
    for (final id in necesarios.where((id) => !enNube.contains(id))) {
      Map<String, dynamic>? fila;

      final especial = ReglasOrden.especiales[id];
      if (especial != null) {
        final ahora = DateTime.now().toIso8601String();
        fila = {
          'id': id,
          'taller_id': DatabaseHelper.activeTallerId,
          'codigo_interno': especial.codigo,
          'nombre': especial.nombre,
          'categoria': 'OTROS',
          'stock_actual': 999999,
          'stock_minimo': 0,
          'precio_costo': 0.0,
          'precio_venta': 0.0,
          'unidad_medida': 'unidad',
          'activo': true,
          'created_at': ahora,
          'updated_at': ahora,
        };
      } else {
        final local = await db
            .query('inventario_repuestos', where: 'id = ?', whereArgs: [id]);
        if (local.isNotEmpty) {
          fila = DatabaseHelper.instance
              .prepararParaNube(Map<String, dynamic>.from(local.first));
          fila['taller_id'] ??= DatabaseHelper.activeTallerId;
        }
      }

      if (fila == null) {
        fallos.add(
          'El repuesto $id no está ni en la nube ni en el teléfono: sus ítems '
          'no se pueden subir.',
        );
        continue;
      }

      try {
        await SupabaseService.client
            .from('inventario_repuestos')
            .upsert(fila, onConflict: 'id');
        creados++;
      } catch (e) {
        // Caso conocido: el repuesto ficticio ya existe pero pertenece a otro
        // taller, así que la RLS lo esconde al leer y bloquea el update.
        fallos.add('Repuesto $id: ${MensajesError.legible(e)}');
      }
    }
    return creados;
  }

  /// Envía filas a la nube. Primero por lotes; si un lote falla, reintenta fila
  /// a fila para que una sola fila mala no arrastre a las demás y para saber
  /// exactamente cuál es.
  Future<int> _subir(
    String tabla,
    List<Map<String, dynamic>> filas,
    String etiqueta,
    List<String> fallos,
  ) async {
    var subidas = 0;
    for (var i = 0; i < filas.length; i += _tamanoLote) {
      final lote = filas.sublist(
          i, i + _tamanoLote > filas.length ? filas.length : i + _tamanoLote);
      try {
        await SupabaseService.client.from(tabla).upsert(lote, onConflict: 'id');
        subidas += lote.length;
      } catch (_) {
        for (final fila in lote) {
          try {
            await SupabaseService.client
                .from(tabla)
                .upsert(fila, onConflict: 'id');
            subidas++;
          } catch (e) {
            fallos.add('$etiqueta · fila ${fila['id']}: $e');
          }
        }
      }
    }
    return subidas;
  }

  /// Copia `monto_pagado` / `saldo_pendiente` / `estado_pago` del teléfono a la
  /// nube, solo cuando el teléfono tiene registrado **más** pago que la nube.
  ///
  /// Con esa condición la operación no puede destruir nada: si la nube ya
  /// estuviera al día, no se toca. No se recalculan totales — `total_estimado`
  /// y `subtotal_repuestos` en la nube son lo único que sobrevivió intacto.
  Future<int> _sincronizarPagos(Database db, List<String> fallos) async {
    var actualizadas = 0;
    try {
      final res = await SupabaseService.client
          .from('ordenes_mantenimiento')
          .select('id, monto_pagado')
          .limit(20000);
      final enNube = <String, double>{
        for (final fila in res as List)
          (fila as Map)['id'] as String:
              (fila['monto_pagado'] as num?)?.toDouble() ?? 0.0
      };

      // Las columnas de pago solo existen si la base local pasó por la
      // migración v6. En una instalación nueva anterior al 12/08/2026 la tabla
      // se creaba sin ellas, y pedirlas rompía todo el paso con
      // «no such column: monto_pagado».
      final columnas = <String>{
        for (final c in await db.rawQuery(
            "SELECT name FROM pragma_table_info('ordenes_mantenimiento')"))
          c['name'] as String
      };
      if (!columnas.contains('monto_pagado')) {
        fallos.add(
          'Este teléfono tiene una versión antigua de la base local y no '
          'guarda el estado de pago. Los abonos sí se subieron; el saldo de '
          'cada orden se recalcula desde ellos.',
        );
        return 0;
      }

      for (final fila in await db.query(
        'ordenes_mantenimiento',
        columns: ['id', 'monto_pagado', 'saldo_pendiente', 'estado_pago'],
      )) {
        final id = fila['id'] as String;
        if (!enNube.containsKey(id)) continue;

        final local = (fila['monto_pagado'] as num?)?.toDouble() ?? 0.0;
        if (local <= enNube[id]!) continue;

        try {
          await SupabaseService.client.from('ordenes_mantenimiento').update({
            'monto_pagado': local,
            'saldo_pendiente': (fila['saldo_pendiente'] as num?)?.toDouble(),
            'estado_pago': fila['estado_pago'],
          }).eq('id', id);
          actualizadas++;
        } catch (e) {
          fallos.add('Estado de pago: ${MensajesError.legible(e)}');
        }
      }
    } catch (e) {
      fallos.add('Estado de pago: ${MensajesError.legible(e)}');
    }
    return actualizadas;
  }
}
