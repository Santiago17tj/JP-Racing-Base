import 'package:flutter/foundation.dart';
import 'package:moto_taller_app/core/dominio/mensajes_error.dart';
import 'package:moto_taller_app/core/dominio/reglas_orden.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/repuesto.dart';
import '../models/historial_stock.dart';
import '../models/cliente.dart';
import '../models/vehiculo.dart';
import '../models/orden_mantenimiento.dart';
import '../models/orden_item.dart';
import '../models/registro_caja.dart';
import '../models/perfil_taller.dart';
import '../models/abono.dart';
import '../../core/constants/enums.dart';
import '../../core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Singleton para operaciones CRUD sobre la Base de Datos.
///
/// Implementa una estrategia híbrida:
/// - En dispositivos móviles (Android/iOS): Usa SQLite real (`sqflite`).
/// - En Web: Utiliza una base de datos simulada en memoria para evitar errores
///   con WebAssembly/Service Workers (`sqflite_sw.js`) en servidores locales.
class DatabaseHelper {
  static String? activeTallerId;

  // Sin datos de ejemplo tampoco en web: mezclarlos con los reales convierte
  // la única superficie de verificación en algo en lo que no se puede confiar.
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError(
          'SQLite no está inicializado en web. Usando simulación en memoria.');
    }
    _database ??= await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'moto_taller.db');

    return await openDatabase(
      path,
      version: 8,
      onCreate: (db, version) async {
        await _onCreate(db, version);
        await _createCajaTable(db);
        await _createPerfilTallerTable(db);
        await _createAbonosTable(db);
        // Se repara también al crear: si el CREATE TABLE y esta lista se
        // desincronizan, converge igual en vez de romperse en silencio.
        await _repararColumnasFaltantes(db);
      },
      onUpgrade: _onUpgrade,
    );
  }

  /// Columnas que la app escribe y que deben existir sí o sí en el teléfono.
  ///
  /// Se comprueban en cada arranque porque la deriva ya ocurrió: una base
  /// creada desde cero en la versión 6 no tenía los campos de la DIAN ni los de
  /// pago —solo los añadía la migración, y quien instalaba de cero nunca pasaba
  /// por ella—. El efecto era brutal y silencioso: al bajar los clientes de la
  /// nube, el `insert` local fallaba con «no such column» y la transacción
  /// entera se caía, así que el teléfono se quedaba con **cero** clientes
  /// teniendo doce en la nube. Sin clientes no se puede crear una orden.
  static const Map<String, Map<String, String>> _columnasExigidas = {
    'clientes': {
      'digito_verificacion': 'TEXT',
      'regimen_fiscal': 'TEXT',
      'codigo_municipio_dane': "TEXT DEFAULT '68001'",
    },
    'ordenes_mantenimiento': {
      'monto_pagado': 'REAL NOT NULL DEFAULT 0',
      'saldo_pendiente': 'REAL NOT NULL DEFAULT 0',
      'estado_pago': "TEXT NOT NULL DEFAULT 'pendiente'",
      'fotos_estado': 'TEXT',
      'es_cotizacion': 'INTEGER NOT NULL DEFAULT 0',
    },
  };

  /// Añade las columnas de [_columnasExigidas] que falten. Idempotente: se
  /// puede correr en cada arranque sin efecto si ya están todas.
  Future<void> _repararColumnasFaltantes(Database db) async {
    for (final tabla in _columnasExigidas.entries) {
      Set<String> existentes;
      try {
        existentes = {
          for (final c in await db
              .rawQuery("SELECT name FROM pragma_table_info('${tabla.key}')"))
            c['name'] as String
        };
      } catch (e) {
        debugPrint('No se pudo inspeccionar ${tabla.key}: $e');
        continue;
      }

      for (final columna in tabla.value.entries) {
        if (existentes.contains(columna.key)) continue;
        try {
          await db.execute(
              'ALTER TABLE ${tabla.key} ADD COLUMN ${columna.key} ${columna.value}');
          debugPrint('Reparada ${tabla.key}.${columna.key}');
        } catch (e) {
          debugPrint('No se pudo añadir ${tabla.key}.${columna.key}: $e');
        }
      }
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createCajaTable(db);
    }
    if (oldVersion < 3) {
      await db.execute(
          'ALTER TABLE ordenes_mantenimiento ADD COLUMN es_cotizacion INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 4) {
      try {
        await db.execute(
            'ALTER TABLE ordenes_mantenimiento ADD COLUMN fotos_estado TEXT');
      } catch (e) {
        debugPrint('Migration version 4 warning (fotos_estado): $e');
      }
    }
    if (oldVersion < 5) {
      await _createPerfilTallerTable(db);
    }
    if (oldVersion < 6) {
      await _migrarVersion6(db);
    }
    if (oldVersion < 7) {
      // Repara las bases creadas desde cero en la v6, a las que `_onCreate`
      // dejó sin las columnas de la DIAN ni las de pago.
      await _repararColumnasFaltantes(db);
    }
    if (oldVersion < 8) {
      await _quitarUnicidadLocal(db);
    }
  }

  /// Quita las restricciones UNIQUE de `clientes.numero_documento` y
  /// `vehiculos.placa_patente`.
  ///
  /// La nube **no** tiene esas restricciones, así que sí admite dos clientes
  /// con el mismo documento o dos motos con la misma placa —cosa que pasa de
  /// verdad: en producción hay un documento repetido cuatro veces y una placa
  /// repetida cuatro veces—. Al bajarlos, SQLite aplicaba
  /// `ConflictAlgorithm.replace` y **cada duplicado borraba al anterior**: de
  /// 14 clientes bajados quedaban 10, y de 13 motos quedaban 9. Sin un solo
  /// error, sin rastro.
  ///
  /// SQLite no sabe eliminar una restricción, así que se reconstruye la tabla.
  Future<void> _quitarUnicidadLocal(Database db) async {
    // Los dos `PRAGMA` se ponen una sola vez y se restauran pase lo que pase:
    //
    //  · `foreign_keys = OFF` para poder renombrar y borrar tablas a las que
    //    otras apuntan.
    //  · `legacy_alter_table = ON` porque, sin él, `RENAME TO` reescribe las
    //    llaves foráneas de las demás tablas para que apunten a
    //    `<tabla>_viejo` — que se borra tres líneas después, dejando
    //    `orden_items`, `orden_abonos` e `historial_stock` con referencias a
    //    una tabla inexistente.
    await db.execute('PRAGMA foreign_keys = OFF');
    await db.execute('PRAGMA legacy_alter_table = ON');
    try {
      for (final tabla in ['clientes', 'vehiculos', 'ordenes_mantenimiento']) {
        try {
          final columnas =
              await db.rawQuery("SELECT name FROM pragma_table_info('$tabla')");
          if (columnas.isEmpty) continue;
          final nombres = columnas.map((c) => c['name'] as String).join(', ');

          await db.transaction((txn) async {
            await txn.execute('ALTER TABLE $tabla RENAME TO ${tabla}_viejo');
            switch (tabla) {
              case 'clientes':
                await _crearTablaClientes(txn);
              case 'vehiculos':
                await _crearTablaVehiculos(txn);
              default:
                await _crearTablaOrdenes(txn);
            }
            await txn.execute(
                'INSERT OR IGNORE INTO $tabla ($nombres) SELECT $nombres FROM ${tabla}_viejo');
            await txn.execute('DROP TABLE ${tabla}_viejo');
          });
          _columnasLocales.remove(tabla);
          debugPrint('Reconstruida $tabla sin UNIQUE');
        } catch (e) {
          debugPrint('No se pudo reconstruir $tabla: $e');
        }
      }
    } finally {
      // Sin esto, un fallo a mitad dejaría la base sin integridad referencial
      // y con la semántica antigua de ALTER TABLE durante toda la sesión.
      await db.execute('PRAGMA legacy_alter_table = OFF');
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  Future<void> _migrarVersion6(Database db) async {
    try {
      await db
          .execute('ALTER TABLE clientes ADD COLUMN digito_verificacion TEXT');
    } catch (e) {
      debugPrint('Migration v6 warning: $e');
    }
    try {
      await db.execute(
          "ALTER TABLE clientes ADD COLUMN regimen_fiscal TEXT DEFAULT 'no_responsable'");
    } catch (e) {
      debugPrint('Migration v6 warning: $e');
    }
    try {
      await db.execute(
          "ALTER TABLE clientes ADD COLUMN codigo_municipio_dane TEXT DEFAULT '68001'");
    } catch (e) {
      debugPrint('Migration v6 warning: $e');
    }

    try {
      await db.execute(
          'ALTER TABLE ordenes_mantenimiento ADD COLUMN monto_pagado REAL DEFAULT 0.0');
    } catch (e) {
      debugPrint('Migration v6 warning: $e');
    }
    try {
      await db.execute(
          'ALTER TABLE ordenes_mantenimiento ADD COLUMN saldo_pendiente REAL DEFAULT 0.0');
    } catch (e) {
      debugPrint('Migration v6 warning: $e');
    }
    try {
      await db.execute(
          "ALTER TABLE ordenes_mantenimiento ADD COLUMN estado_pago TEXT DEFAULT 'pendiente'");
    } catch (e) {
      debugPrint('Migration v6 warning: $e');
    }

    await _createAbonosTable(db);
  }

  Future<void> _createAbonosTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS orden_abonos (
        id TEXT PRIMARY KEY,
        orden_id TEXT NOT NULL,
        monto REAL NOT NULL,
        metodo_pago TEXT NOT NULL,
        fecha TEXT NOT NULL,
        notas TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (orden_id) REFERENCES ordenes_mantenimiento(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createPerfilTallerTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS perfil_taller (
        id TEXT PRIMARY KEY,
        usuario_administrador_id TEXT NOT NULL,
        nombre_taller TEXT NOT NULL,
        logo_url TEXT,
        telefono TEXT,
        direccion TEXT,
        ciudad TEXT,
        moneda TEXT DEFAULT 'COP',
        porcentaje_impuesto_defecto REAL DEFAULT 0.0,
        terminos_condiciones_factura TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createCajaTable(Database db) async {
    await db.execute('''
      CREATE TABLE registro_caja (
        id TEXT PRIMARY KEY,
        taller_id TEXT,
        tipo TEXT NOT NULL,
        monto REAL NOT NULL,
        concepto TEXT NOT NULL,
        referencia_id TEXT,
        fecha TEXT NOT NULL
      )
    ''');
  }

  /// Tabla local de clientes.
  ///
  /// `numero_documento` **no lleva UNIQUE** a propósito: la nube no lo exige y
  /// en producción hay documentos repetidos. Con UNIQUE, al bajar los datos
  /// cada repetido borraba al anterior y el teléfono perdía clientes sin decir
  /// nada. Ver `_quitarUnicidadLocal`.
  Future<void> _crearTablaClientes(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE clientes (
        id TEXT PRIMARY KEY,
        taller_id TEXT,
        nombre TEXT NOT NULL,
        apellido TEXT NOT NULL,
        tipo_documento TEXT NOT NULL,
        numero_documento TEXT NOT NULL,
        digito_verificacion TEXT,
        regimen_fiscal TEXT,
        codigo_municipio_dane TEXT DEFAULT '68001',
        email TEXT,
        telefono TEXT NOT NULL,
        direccion TEXT,
        ciudad TEXT,
        notas TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  /// Tabla local de vehículos. `placa_patente` tampoco lleva UNIQUE, por el
  /// mismo motivo que el documento del cliente.
  Future<void> _crearTablaVehiculos(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE vehiculos (
        id TEXT PRIMARY KEY,
        taller_id TEXT,
        cliente_id TEXT NOT NULL,
        placa_patente TEXT NOT NULL,
        marca TEXT NOT NULL,
        modelo TEXT NOT NULL,
        anio INTEGER NOT NULL,
        kilometraje_actual INTEGER NOT NULL DEFAULT 0,
        color TEXT,
        numero_motor TEXT,
        numero_chasis TEXT,
        notas TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id)
      )
    ''');
  }

  /// Tabla local de órdenes. `numero_orden` no lleva UNIQUE: en la nube la
  /// unicidad es por taller, y un teléfono puede tener datos de dos cuentas.
  /// Con UNIQUE global, la orden de un taller borraba la del otro en silencio.
  Future<void> _crearTablaOrdenes(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE ordenes_mantenimiento (
        id TEXT PRIMARY KEY,
        taller_id TEXT,
        numero_orden TEXT NOT NULL,
        cliente_id TEXT NOT NULL,
        vehiculo_id TEXT NOT NULL,
        estado TEXT NOT NULL,
        tipo_servicio TEXT NOT NULL,
        kilometraje_ingreso INTEGER NOT NULL,
        descripcion_problema TEXT,
        diagnostico TEXT,
        notas_mecanico TEXT,
        mecanico_asignado TEXT,
        costo_mano_obra REAL NOT NULL DEFAULT 0,
        subtotal_repuestos REAL NOT NULL DEFAULT 0,
        total_estimado REAL NOT NULL DEFAULT 0,
        monto_pagado REAL NOT NULL DEFAULT 0,
        saldo_pendiente REAL NOT NULL DEFAULT 0,
        estado_pago TEXT NOT NULL DEFAULT 'pendiente',
        fecha_ingreso TEXT NOT NULL,
        fecha_promesa TEXT,
        fecha_entrega TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        es_cotizacion INTEGER NOT NULL DEFAULT 0,
        fotos_estado TEXT,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id),
        FOREIGN KEY (vehiculo_id) REFERENCES vehiculos(id)
      )
    ''');
  }

  Future<void> _onCreate(Database db, int version) async {
    await _crearTablaClientes(db);
    await _crearTablaVehiculos(db);

    // Tabla: inventario_repuestos
    await db.execute('''
      CREATE TABLE inventario_repuestos (
        id TEXT PRIMARY KEY,
        taller_id TEXT,
        codigo_interno TEXT NOT NULL,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        foto_url TEXT,
        categoria TEXT NOT NULL,
        subcategoria TEXT,
        marca_repuesto TEXT,
        numero_parte TEXT,
        stock_actual INTEGER NOT NULL DEFAULT 0,
        stock_minimo INTEGER NOT NULL DEFAULT 5 CHECK(stock_minimo >= 0),
        precio_costo REAL NOT NULL CHECK(precio_costo >= 0),
        precio_venta REAL NOT NULL CHECK(precio_venta >= 0),
        ubicacion_almacen TEXT,
        unidad_medida TEXT DEFAULT 'unidad',
        activo INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await _crearTablaOrdenes(db);

    // Tabla: orden_items
    await db.execute('''
      CREATE TABLE orden_items (
        id TEXT PRIMARY KEY,
        orden_id TEXT NOT NULL,
        repuesto_id TEXT NOT NULL,
        descripcion TEXT NOT NULL,
        cantidad INTEGER NOT NULL,
        precio_unitario REAL NOT NULL,
        descuento REAL NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (orden_id) REFERENCES ordenes_mantenimiento(id),
        FOREIGN KEY (repuesto_id) REFERENCES inventario_repuestos(id)
      )
    ''');

    // Tabla: historial_stock
    await db.execute('''
      CREATE TABLE historial_stock (
        id TEXT PRIMARY KEY,
        repuesto_id TEXT NOT NULL,
        orden_id TEXT,
        tipo_movimiento TEXT NOT NULL,
        cantidad INTEGER NOT NULL,
        stock_anterior INTEGER NOT NULL,
        stock_posterior INTEGER NOT NULL,
        motivo TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (repuesto_id) REFERENCES inventario_repuestos(id)
      )
    ''');

    // Índices
    await db.execute(
        'CREATE INDEX idx_repuestos_categoria ON inventario_repuestos(categoria)');
    await db.execute(
        'CREATE INDEX idx_repuestos_nombre ON inventario_repuestos(nombre)');
    await db.execute(
        'CREATE INDEX idx_historial_repuesto ON historial_stock(repuesto_id, created_at DESC)');
    await db.execute(
        'CREATE INDEX idx_ordenes_estado ON ordenes_mantenimiento(estado)');
    await db.execute(
        'CREATE INDEX idx_ordenes_cliente ON ordenes_mantenimiento(cliente_id)');
    await db
        .execute('CREATE INDEX idx_orden_items_orden ON orden_items(orden_id)');

    // Sin datos de ejemplo. Antes se sembraban clientes, motos, órdenes y
    // repuestos ficticios en cada instalación, y traía dos problemas:
    //
    //  · Los clientes, motos y órdenes usaban ids inventados ('c1-uuid',
    //    'o1-uuid'…) que no son UUID. La nube los rechaza con 22P02 siempre,
    //    así que ensuciaban el teléfono sin poder sincronizar jamás.
    //  · Los repuestos llevaban UUID escritos a mano, **idénticos en todas las
    //    instalaciones**. El primer taller que subía se quedaba con esos ids;
    //    a los demás la RLS les bloqueaba el upsert y su inventario no
    //    sincronizaba, en silencio.
    //
    // Un taller real quiere su propio inventario, no pastillas Brembo de
    // muestra con precios en dólares.
  }

  // ──────────────────────────────────────────────
  //  Mapeos y Helpers para Supabase / DB
  // ──────────────────────────────────────────────

  bool get _useCloud =>
      SupabaseService.isConfigured &&
      SupabaseService.client.auth.currentUser != null;

  Map<String, dynamic> _prepareToDb(dynamic map, {bool forSupabase = false}) {
    final newMap = Map<String, dynamic>.from(map);

    if (newMap.containsKey('mecanico_assigned')) {
      newMap['mecanico_asignado'] = newMap.remove('mecanico_assigned');
    }

    if (newMap.containsKey('activo')) {
      final val = newMap['activo'];
      if (forSupabase) {
        newMap['activo'] = (val == 1 || val == true);
      } else {
        newMap['activo'] = (val == true || val == 1) ? 1 : 0;
      }
    }

    if (newMap.containsKey('es_cotizacion')) {
      final val = newMap['es_cotizacion'];
      if (forSupabase) {
        newMap['es_cotizacion'] = (val == 1 || val == true);
      } else {
        newMap['es_cotizacion'] = (val == true || val == 1) ? 1 : 0;
      }
    }

    if (forSupabase) {
      if (newMap.containsKey('placa_patente')) {
        newMap['placa'] = newMap['placa_patente'];
      }
      if (newMap.containsKey('kilometraje_actual')) {
        newMap['kilometraje'] = newMap['kilometraje_actual'];
      }
      if (newMap.containsKey('estado')) {
        final String est = (newMap['estado'] as String).toUpperCase();
        if (est.contains('DIAG')) {
          newMap['estado'] = 'EN_DIAGNOSTICO';
        } else if (est.contains('REPARAC')) {
          newMap['estado'] = 'EN_REPARACION';
        } else if (est.contains('LISTA') || est.contains('ENTREGA')) {
          if (est == 'ENTREGADA') {
            newMap['estado'] = 'ENTREGADA';
          } else {
            newMap['estado'] = 'LISTA_PARA_ENTREGA';
          }
        } else if (est.contains('CANCEL')) {
          newMap['estado'] = 'CANCELADA';
        } else {
          newMap['estado'] = 'INGRESADA';
        }
      }

      // Remover columnas que son GENERATED ALWAYS en Supabase
      newMap.remove('subtotal');

      // historial_stock nombra distinto estas dos columnas en la nube.
      if (newMap.containsKey('stock_anterior')) {
        newMap['stock_antes'] = newMap.remove('stock_anterior');
      }
      if (newMap.containsKey('stock_posterior')) {
        newMap['stock_despues'] = newMap.remove('stock_posterior');
      }
    }

    return newMap;
  }

  /// Traduce una fila al formato exacto que espera Supabase.
  ///
  /// Es la misma transformación que usan todas las escrituras a la nube
  /// (`_prepareToDb(forSupabase: true)`), expuesta porque la necesitan el
  /// servicio de rescate y la prueba de contrato del esquema.
  ///
  /// Ver `test/contrato_esquema_nube_test.dart`: enviar una columna que no
  /// existe hace que PostgREST rechace la fila entera, y ese error se perdía
  /// en un `catch`. Fue lo que dejó de sincronizar a los clientes desde el
  /// 30/07/2026, cuando el modelo `Cliente` ganó los campos de la DIAN.
  Map<String, dynamic> prepararParaNube(Map<String, dynamic> map) =>
      _prepareToDb(map, forSupabase: true);

  /// Traduce una fila al formato que espera el SQLite del teléfono.
  ///
  /// Expuesto para `test/contrato_esquema_local_test.dart`, que comprueba que
  /// toda columna que la app escribe existe en el `CREATE TABLE`. Sin esa
  /// prueba se colaron dos bugs que solo aparecían en instalaciones nuevas: la
  /// tabla se creaba sin `monto_pagado` y sin los campos de la DIAN, y solo se
  /// añadían al *actualizar* desde una versión anterior.
  Map<String, dynamic> prepararParaLocal(Map<String, dynamic> map) =>
      _prepareToDb(map, forSupabase: false);

  /// Igual que `_prepareFromDb`, expuesto para las pruebas de ida y vuelta.
  ///
  /// La traducción tiene que ser reversible: si `stock_antes` no vuelve a
  /// `stock_anterior`, el modelo lee 0 y el historial de stock queda mal sin
  /// que nada falle.
  @visibleForTesting
  Map<String, dynamic> interpretarDeNube(Map<String, dynamic> map) =>
      _prepareFromDb(map);

  Map<String, dynamic> _prepareFromDb(dynamic map) {
    final newMap = Map<String, dynamic>.from(map);

    if (newMap.containsKey('mecanico_asignado')) {
      newMap['mecanico_assigned'] = newMap['mecanico_asignado'];
    }

    if (newMap.containsKey('activo')) {
      final val = newMap['activo'];
      newMap['activo'] = (val == true || val == 1) ? 1 : 0;
    }

    if (newMap.containsKey('es_cotizacion')) {
      final val = newMap['es_cotizacion'];
      newMap['es_cotizacion'] = (val == true || val == 1) ? 1 : 0;
    }

    // Vuelta de los nombres que difieren en la nube.
    if (newMap.containsKey('stock_antes') &&
        !newMap.containsKey('stock_anterior')) {
      newMap['stock_anterior'] = newMap['stock_antes'];
    }
    if (newMap.containsKey('stock_despues') &&
        !newMap.containsKey('stock_posterior')) {
      newMap['stock_posterior'] = newMap['stock_despues'];
    }

    if (newMap.containsKey('placa') && !newMap.containsKey('placa_patente')) {
      newMap['placa_patente'] = newMap['placa'];
    }
    if (newMap.containsKey('kilometraje') &&
        !newMap.containsKey('kilometraje_actual')) {
      newMap['kilometraje_actual'] = newMap['kilometraje'];
    }
    // `fecha_ingreso` solo existe en las órdenes. Antes se rellenaba en toda
    // fila que tuviera `created_at` —es decir, en todas—, y al guardar un
    // repuesto o un cliente bajado de la nube el insert local moría con
    // «no such column: fecha_ingreso». Como la descarga entera iba en una sola
    // transacción, un teléfono recién instalado se quedaba con CERO datos
    // teniendo todo en la nube.
    final pareceOrden = newMap.containsKey('numero_orden') ||
        newMap.containsKey('costo_mano_obra');
    if (pareceOrden &&
        newMap.containsKey('created_at') &&
        !newMap.containsKey('fecha_ingreso')) {
      newMap['fecha_ingreso'] = newMap['created_at'];
    }

    return newMap;
  }

  /// Columnas reales de una tabla local, cacheadas por tabla.
  final Map<String, Set<String>> _columnasLocales = {};

  Future<Set<String>> _columnasDe(DatabaseExecutor db, String tabla) async {
    final cacheadas = _columnasLocales[tabla];
    if (cacheadas != null) return cacheadas;
    final filas =
        await db.rawQuery("SELECT name FROM pragma_table_info('$tabla')");
    final columnas = {for (final f in filas) f['name'] as String};
    _columnasLocales[tabla] = columnas;
    return columnas;
  }

  /// Deja de un mapa solo lo que la tabla local sabe guardar.
  ///
  /// Es la red de seguridad contra la deriva de esquemas: si la nube gana una
  /// columna que el teléfono todavía no tiene, la fila entra igual sin ese
  /// campo, en vez de perderse entera con «no such column».
  Future<Map<String, dynamic>> _soloColumnasDe(
      DatabaseExecutor db, String tabla, Map<String, dynamic> mapa) async {
    final columnas = await _columnasDe(db, tabla);
    return {
      for (final e in mapa.entries)
        if (columnas.contains(e.key)) e.key: e.value
    };
  }

  /// Descarga todo el historial y estado actual desde Supabase a SQLite local.
  ///
  /// No hace nada en web: allí cada consulta va directa a Supabase, así que no
  /// hay copia local que rellenar. Antes se bajaban cinco tablas para tirarlas.
  Future<void> sincronizarDesdeNube(String tallerId) async {
    if (!SupabaseService.isConfigured || kIsWeb) return;
    try {
      debugPrint(
          '🔄 Iniciando sincronización desde la nube para el taller: $tallerId');

      // 0. Perfil de Taller
      final tallerRes = await SupabaseService.client
          .from('perfil_taller')
          .select()
          .eq('id', tallerId)
          .maybeSingle();
      if (tallerRes != null) {
        if (!kIsWeb) {
          final db = await database;
          // Verificar si el local es más reciente para no sobreescribirlo con datos viejos de la nube
          final localTaller = await db
              .query('perfil_taller', where: 'id = ?', whereArgs: [tallerId]);
          bool shouldUpdate = true;
          if (localTaller.isNotEmpty) {
            final localUpdate = DateTime.tryParse(
                    localTaller.first['updated_at'] as String? ?? '') ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final cloudUpdate =
                DateTime.tryParse(tallerRes['updated_at'] as String? ?? '') ??
                    DateTime.fromMillisecondsSinceEpoch(0);
            if (localUpdate.isAfter(cloudUpdate)) {
              shouldUpdate = false;
              // Intentar subir a la nube porque el local es más reciente
              try {
                final localMapToCloud = _prepareToDb(
                    Map<String, dynamic>.from(localTaller.first),
                    forSupabase: true);
                await SupabaseService.client
                    .from('perfil_taller')
                    .upsert(localMapToCloud);
              } catch (_) {}
            }
          }
          if (shouldUpdate) {
            await db.insert('perfil_taller',
                _prepareToDb(_prepareFromDb(tallerRes), forSupabase: false),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      // 1. Clientes
      final clientesRes = await SupabaseService.client
          .from('clientes')
          .select()
          .eq('taller_id', tallerId);

      // 2. Vehículos
      final vehiculosRes = await SupabaseService.client
          .from('vehiculos')
          .select()
          .eq('taller_id', tallerId);

      // 3. Repuestos
      final repuestosRes = await SupabaseService.client
          .from('inventario_repuestos')
          .select()
          .eq('taller_id', tallerId);

      // 4. Órdenes
      final ordenesRes = await SupabaseService.client
          .from('ordenes_mantenimiento')
          .select()
          .eq('taller_id', tallerId);

      // 5. Caja
      final cajaRes = await SupabaseService.client
          .from('registro_caja')
          .select()
          .eq('taller_id', tallerId);

      // Guardar en el teléfono. En web no hay dónde: allí se lee siempre de la
      // nube, sin copia intermedia que pueda quedarse vieja.
      if (!kIsWeb) {
        final db = await database;

        // Sin transacción envolvente y fila a fila, a propósito.
        //
        // Antes toda la descarga iba en una única transacción: bastaba que una
        // fila fallara para que se deshiciera TODO y el teléfono se quedara con
        // cero clientes, cero motos y cero órdenes teniendo todo en la nube.
        // Con `debugPrint` anulado en release, además, sin rastro. Ahora cada
        // fila se guarda por su cuenta y lo que falla se cuenta y se informa.
        ultimoResumenDescarga = await _guardarDescarga(db, {
          'inventario_repuestos': repuestosRes as List, // primero: las FK
          'clientes': clientesRes as List,
          'vehiculos': vehiculosRes as List,
          'ordenes_mantenimiento': ordenesRes as List,
          'registro_caja': cajaRes as List,
        });

        // Los ítems se piden aparte porque dependen de las órdenes bajadas.
        final ordenIds = [
          for (final o in ordenesRes) (o as Map)['id'] as String
        ];
        if (ordenIds.isNotEmpty) {
          final itemsRes = await SupabaseService.client
              .from('orden_items')
              .select()
              .inFilter('orden_id', ordenIds);
          final resumenItems =
              await _guardarDescarga(db, {'orden_items': itemsRes as List});
          ultimoResumenDescarga = '$ultimoResumenDescarga · $resumenItems';
        }
      }
      debugPrint('✅ Sincronización desde la nube: $ultimoResumenDescarga');
    } catch (e) {
      ultimoResumenDescarga = 'Falló la descarga: ${MensajesError.legible(e)}';
      debugPrint('🚨 Error durante la sincronización desde la nube: $e');
    }
  }

  /// Resultado legible de la última descarga, para poder verlo en pantalla en
  /// lugar de perderlo en un `debugPrint` que en release no existe.
  static String? ultimoResumenDescarga;

  /// Borra del teléfono los datos que pertenecen a otros talleres.
  ///
  /// Un mismo teléfono usado con dos cuentas iba acumulando las dos: en pruebas
  /// llegó a tener 51 filas ajenas, y creciendo con cada cambio de sesión. No
  /// era peligroso —la nube las rechaza y las consultas filtran por taller—
  /// pero son datos de un taller sentados en el equipo de otro, y ensucian
  /// todos los recuentos.
  ///
  /// Solo borra lo que tiene dueño distinto al activo. Las filas sin
  /// `taller_id` se conservan: son anteriores al campo y pertenecen a quien use
  /// el teléfono. Se ejecuta después de iniciar sesión, cuando ya se sabe cuál
  /// es el taller.
  Future<int> limpiarDatosDeOtrosTalleres(String tallerActivo) async {
    if (kIsWeb) return 0;
    final db = await database;
    var borradas = 0;

    // Orden inverso a las llaves foráneas: primero lo que cuelga de otra cosa.
    const dependientes = {
      'orden_items': 'orden_id',
      'orden_abonos': 'orden_id',
    };
    for (final entrada in dependientes.entries) {
      try {
        borradas += await db.rawDelete('''
          DELETE FROM ${entrada.key} WHERE ${entrada.value} IN (
            SELECT id FROM ordenes_mantenimiento
            WHERE taller_id IS NOT NULL AND taller_id != ?
          )''', [tallerActivo]);
      } catch (e) {
        debugPrint('No se pudo limpiar ${entrada.key}: $e');
      }
    }

    try {
      borradas += await db.rawDelete('''
        DELETE FROM historial_stock WHERE repuesto_id IN (
          SELECT id FROM inventario_repuestos
          WHERE taller_id IS NOT NULL AND taller_id != ?
        )''', [tallerActivo]);
    } catch (e) {
      debugPrint('No se pudo limpiar historial_stock: $e');
    }

    for (final tabla in [
      'ordenes_mantenimiento',
      'vehiculos',
      'clientes',
      'inventario_repuestos',
      'registro_caja',
    ]) {
      try {
        borradas += await db.delete(tabla,
            where: 'taller_id IS NOT NULL AND taller_id != ?',
            whereArgs: [tallerActivo]);
      } catch (e) {
        debugPrint('No se pudo limpiar $tabla: $e');
      }
    }

    if (borradas > 0) {
      debugPrint('Limpiadas $borradas filas de otros talleres');
    }
    return borradas;
  }

  /// Guarda fila a fila lo bajado de la nube. Devuelve un resumen contable.
  Future<String> _guardarDescarga(
      Database db, Map<String, List<dynamic>> porTabla) async {
    final partes = <String>[];

    for (final entrada in porTabla.entries) {
      var guardadas = 0;
      final errores = <String>[];

      for (final fila in entrada.value) {
        try {
          var preparada = _prepareFromDb(fila);

          // El apellido llegó vacío en clientes antiguos: se parte el nombre.
          if (entrada.key == 'clientes' &&
              (preparada['apellido'] == null ||
                  (preparada['apellido'] as String).trim().isEmpty)) {
            final completo = (preparada['nombre'] ?? '') as String;
            final partesNombre = completo.trim().split(' ');
            preparada['nombre'] =
                partesNombre.isNotEmpty ? partesNombre.first : completo;
            preparada['apellido'] =
                partesNombre.length > 1 ? partesNombre.sublist(1).join(' ') : '';
          }

          final local = await _soloColumnasDe(
              db, entrada.key, _prepareToDb(preparada, forSupabase: false));
          await db.insert(entrada.key, local,
              conflictAlgorithm: ConflictAlgorithm.replace);
          guardadas++;
        } catch (e) {
          if (errores.length < 3) errores.add(MensajesError.legible(e));
        }
      }

      partes.add(errores.isEmpty
          ? '${entrada.key}: $guardadas'
          : '${entrada.key}: $guardadas ok, ${entrada.value.length - guardadas} con error (${errores.first})');
    }

    return partes.join(' · ');
  }

  // ──────────────────────────────────────────────
  //  CRUD: Perfil de Taller
  // ──────────────────────────────────────────────

  Future<PerfilTaller> insertPerfilTaller(PerfilTaller taller) async {
    var tallerToSave = taller;
    if (_useCloud) {
      try {
        final cloudMap = taller.toMap();
        final response = await SupabaseService.client
            .from('perfil_taller')
            .upsert(cloudMap, onConflict: 'id')
            .select()
            .single();
        tallerToSave = PerfilTaller.fromMap(
            _prepareFromDb(Map<String, dynamic>.from(response)));
      } catch (e) {
        debugPrint('Error inserting perfil_taller to Supabase: $e');
        // No hacer rethrow, permitir que falle la nube y guarde en SQLite como fallback.
      }
    }
    if (kIsWeb) {
      return tallerToSave;
    }
    final db = await database;
    await db.insert('perfil_taller', tallerToSave.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
    return tallerToSave;
  }

  Future<PerfilTaller?> getPerfilTaller(String usuarioId) async {
    if (_useCloud) {
      try {
        final response = await SupabaseService.client
            .from('perfil_taller')
            .select()
            .eq('usuario_administrador_id', usuarioId)
            .maybeSingle();
        if (response != null) {
          final data = Map<String, dynamic>.from(response as Map);
          final taller = PerfilTaller.fromMap(_prepareFromDb(data));
          if (!kIsWeb) {
            final db = await database;
            await db.insert('perfil_taller', taller.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
          }
          return taller;
        }
      } catch (e) {
        debugPrint('Error getting perfil_taller from Supabase: $e');
      }
    }

    if (!kIsWeb) {
      final db = await database;
      final maps = await db.query(
        'perfil_taller',
        where: 'usuario_administrador_id = ?',
        whereArgs: [usuarioId],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        return PerfilTaller.fromMap(_prepareFromDb(maps.first));
      }
    }
    return null;
  }

  /// Consulta SOLO la base de datos SQLite local, sin tocar la nube.
  /// Usado como fallback offline en [TallerProvider.cargarTaller].
  Future<PerfilTaller?> getPerfilTallerLocal(String usuarioId) async {
    if (kIsWeb) return null;
    final db = await database;
    final maps = await db.query(
      'perfil_taller',
      where: 'usuario_administrador_id = ?',
      whereArgs: [usuarioId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return PerfilTaller.fromMap(_prepareFromDb(maps.first));
  }

  /// Guarda el perfil del taller SOLO en SQLite local, sin escribir en la nube.
  /// Llamado desde [TallerProvider.cargarTaller] tras descargar datos de Supabase.
  Future<void> savePerfilTallerLocal(PerfilTaller taller) async {
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
      'perfil_taller',
      taller.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ──────────────────────────────────────────────
  //  CRUD: Clientes
  // ──────────────────────────────────────────────

  Future<void> insertCliente(Cliente cliente) async {
    final clienteToSave = cliente.tallerId == null && activeTallerId != null
        ? cliente.copyWith(tallerId: activeTallerId)
        : cliente;
    final map = clienteToSave.toMap();
    if (_useCloud) {
      try {
        final cloudMap = _prepareToDb(map, forSupabase: true);
        await SupabaseService.client.from('clientes').upsert(cloudMap);
      } catch (e) {
        if (e is PostgrestException &&
            e.message.toLowerCase().contains('apellido')) {
          try {
            final fallbackMap = _prepareToDb(map, forSupabase: true);
            final String n = fallbackMap['nombre'] ?? '';
            final String a = fallbackMap['apellido'] ?? '';
            fallbackMap['nombre'] = '$n $a'.trim();
            fallbackMap.remove('apellido');
            await SupabaseService.client.from('clientes').upsert(fallbackMap);
          } catch (innerErr) {
            debugPrint(
                'Error inserting fallback cliente to Supabase: $innerErr');
          }
        } else {
          debugPrint('Error inserting cliente to Supabase: $e');
        }
      }
    }

    // En web no hay SQLite. Antes se guardaba en una lista en memoria que se
    // perdía al recargar: aparentaba haber guardado. La nube es el único
    // destino real, y si falla ya se registró arriba.
    if (kIsWeb) return;

    final db = await database;
    final localMap = _prepareToDb(map, forSupabase: false);
    await db.insert('clientes', localMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Cliente>> getClientes() async {
    if (_useCloud && kIsWeb) {
      try {
        var query =
            SupabaseService.client.from('clientes').select().eq('activo', true);
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        final response = await query.order('nombre');
        final list = (response as List).map((m) {
          final prepared = _prepareFromDb(m);
          if (prepared['apellido'] == null ||
              (prepared['apellido'] as String).trim().isEmpty) {
            final String fullName = prepared['nombre'] ?? '';
            final parts = fullName.trim().split(' ');
            if (parts.length > 1) {
              prepared['nombre'] = parts.first;
              prepared['apellido'] = parts.sublist(1).join(' ');
            } else {
              prepared['nombre'] = fullName;
              prepared['apellido'] = '';
            }
          }
          return Cliente.fromMap(prepared);
        }).toList();
        return list;
      } catch (e) {
        debugPrint('Error fetching clientes from Supabase: $e');
      }
    }

    if (kIsWeb) return const [];

    final db = await database;
    final maps = activeTallerId != null
        ? await db.query('clientes',
            where: 'activo = 1 AND taller_id = ?',
            whereArgs: [activeTallerId],
            orderBy: 'nombre ASC')
        : await db.query('clientes',
            where: 'activo = 1', orderBy: 'nombre ASC');
    return maps.map((m) => Cliente.fromMap(_prepareFromDb(m))).toList();
  }

  Future<Cliente?> getCliente(String id) async {
    if (_useCloud) {
      try {
        var query =
            SupabaseService.client.from('clientes').select().eq('id', id);
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        final response = await query.maybeSingle();
        if (response != null) {
          return Cliente.fromMap(_prepareFromDb(response));
        }
      } catch (e) {
        debugPrint('Error fetching cliente from Supabase: $e');
      }
    }

    if (kIsWeb) return null;

    final db = await database;
    final maps = await db.query('clientes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Cliente.fromMap(_prepareFromDb(maps.first));
  }

  // ──────────────────────────────────────────────
  //  CRUD: Vehículos
  // ──────────────────────────────────────────────

  Future<void> insertVehiculo(Vehiculo vehiculo) async {
    final vehiculoToSave = vehiculo.tallerId == null && activeTallerId != null
        ? vehiculo.copyWith(tallerId: activeTallerId)
        : vehiculo;
    final map = vehiculoToSave.toMap();
    if (_useCloud) {
      try {
        final cloudMap = _prepareToDb(map, forSupabase: true);
        await SupabaseService.client.from('vehiculos').upsert(cloudMap);
      } catch (e) {
        debugPrint('Error inserting vehiculo to Supabase: $e');
      }
    }

    if (kIsWeb) return;

    final db = await database;
    final localMap = _prepareToDb(map, forSupabase: false);
    await db.insert('vehiculos', localMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Vehiculo>> getVehiculosPorCliente(String clienteId) async {
    if (_useCloud && kIsWeb) {
      try {
        var query = SupabaseService.client
            .from('vehiculos')
            .select()
            .eq('cliente_id', clienteId)
            .eq('activo', true);
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        final response = await query;
        return (response as List)
            .map((m) => Vehiculo.fromMap(_prepareFromDb(m)))
            .toList();
      } catch (e) {
        debugPrint('Error fetching vehiculos from Supabase: $e');
      }
    }

    if (kIsWeb) return const [];

    final db = await database;
    final maps = activeTallerId != null
        ? await db.query('vehiculos',
            where: 'cliente_id = ? AND activo = 1 AND taller_id = ?',
            whereArgs: [clienteId, activeTallerId])
        : await db.query('vehiculos',
            where: 'cliente_id = ? AND activo = 1', whereArgs: [clienteId]);
    return maps.map((m) => Vehiculo.fromMap(_prepareFromDb(m))).toList();
  }

  Future<Vehiculo?> getVehiculo(String id) async {
    if (_useCloud && kIsWeb) {
      try {
        var query =
            SupabaseService.client.from('vehiculos').select().eq('id', id);
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        final response = await query.maybeSingle();
        if (response != null) {
          return Vehiculo.fromMap(_prepareFromDb(response));
        }
      } catch (e) {
        debugPrint('Error fetching vehiculo from Supabase: $e');
      }
    }

    if (kIsWeb) return null;

    final db = await database;
    final maps = activeTallerId != null
        ? await db.query('vehiculos',
            where: 'id = ? AND taller_id = ?', whereArgs: [id, activeTallerId])
        : await db.query('vehiculos', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Vehiculo.fromMap(_prepareFromDb(maps.first));
  }

  // ──────────────────────────────────────────────
  //  CRUD: Repuestos
  // ──────────────────────────────────────────────

  Future<void> insertRepuesto(Repuesto repuesto) async {
    final repuestoToSave = repuesto.tallerId == null && activeTallerId != null
        ? repuesto.copyWith(tallerId: activeTallerId)
        : repuesto;
    final map = repuestoToSave.toMap();
    if (_useCloud) {
      try {
        final cloudMap = _prepareToDb(map, forSupabase: true);
        await SupabaseService.client
            .from('inventario_repuestos')
            .upsert(cloudMap);
      } catch (e) {
        debugPrint('Error inserting repuesto to Supabase: $e');
      }
    }

    if (kIsWeb) return;

    final db = await database;
    final localMap = _prepareToDb(map, forSupabase: false);
    await db.insert('inventario_repuestos', localMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Repuesto>> getRepuestos({
    String? busqueda,
    String? categoria,
    bool soloStockBajo = false,
  }) async {
    if (_useCloud && kIsWeb) {
      try {
        var query = SupabaseService.client
            .from('inventario_repuestos')
            .select()
            .eq('activo', true);
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        if (categoria != null) {
          query = query.eq('categoria', categoria);
        }
        final response = await query;
        var list = (response as List)
            .map((m) => Repuesto.fromMap(_prepareFromDb(m)))
            .toList();

        if (busqueda != null && busqueda.isNotEmpty) {
          final q = busqueda.toLowerCase();
          list = list
              .where((r) =>
                  r.nombre.toLowerCase().contains(q) ||
                  r.codigoInterno.toLowerCase().contains(q))
              .toList();
        }
        if (soloStockBajo) {
          list = list.where((r) => r.stockActual <= r.stockMinimo).toList();
        }
        list.sort((a, b) => a.nombre.compareTo(b.nombre));
        return list;
      } catch (e) {
        debugPrint('Error fetching repuestos from Supabase: $e');
      }
    }

    if (kIsWeb) return const [];

    final db = await database;
    final where = <String>['activo = 1'];
    final args = <dynamic>[];

    if (activeTallerId != null) {
      where.add('taller_id = ?');
      args.add(activeTallerId);
    }

    if (busqueda != null && busqueda.isNotEmpty) {
      where.add('(nombre LIKE ? OR codigo_interno LIKE ?)');
      args.add('%$busqueda%');
      args.add('%$busqueda%');
    }
    if (categoria != null) {
      where.add('categoria = ?');
      args.add(categoria);
    }
    if (soloStockBajo) {
      where.add('stock_actual <= stock_minimo');
    }

    final maps = await db.query('inventario_repuestos',
        where: where.join(' AND '), whereArgs: args, orderBy: 'nombre ASC');
    return maps.map((m) => Repuesto.fromMap(_prepareFromDb(m))).toList();
  }

  Future<Repuesto?> getRepuesto(String id) async {
    if (_useCloud && kIsWeb) {
      try {
        var query = SupabaseService.client
            .from('inventario_repuestos')
            .select()
            .eq('id', id);
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        final response = await query.maybeSingle();
        if (response != null) {
          return Repuesto.fromMap(_prepareFromDb(response));
        }
      } catch (e) {
        debugPrint('Error fetching repuesto from Supabase: $e');
      }
    }

    if (kIsWeb) return null;

    final db = await database;
    final maps = activeTallerId != null
        ? await db.query('inventario_repuestos',
            where: 'id = ? AND taller_id = ?', whereArgs: [id, activeTallerId])
        : await db
            .query('inventario_repuestos', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Repuesto.fromMap(_prepareFromDb(maps.first));
  }

  Future<Repuesto?> getRepuestoPorCodigo(String codigoInterno) async {
    if (_useCloud && kIsWeb) {
      try {
        var query = SupabaseService.client
            .from('inventario_repuestos')
            .select()
            .eq('codigo_interno', codigoInterno)
            .eq('activo', true);
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        final response = await query.maybeSingle();
        if (response != null) {
          return Repuesto.fromMap(_prepareFromDb(response));
        }
      } catch (e) {
        debugPrint('Error fetching repuesto from Supabase: $e');
      }
    }

    if (kIsWeb) return null;

    final db = await database;
    final maps = activeTallerId != null
        ? await db.query('inventario_repuestos',
            where: 'codigo_interno = ? AND activo = 1 AND taller_id = ?',
            whereArgs: [codigoInterno, activeTallerId],
            limit: 1)
        : await db.query('inventario_repuestos',
            where: 'codigo_interno = ? AND activo = 1',
            whereArgs: [codigoInterno],
            limit: 1);
    if (maps.isEmpty) return null;
    return Repuesto.fromMap(_prepareFromDb(maps.first));
  }

  Future<void> updateRepuesto(Repuesto repuesto) async {
    final repuestoToSave = repuesto.tallerId == null && activeTallerId != null
        ? repuesto.copyWith(tallerId: activeTallerId)
        : repuesto;
    final map = repuestoToSave.toMap();
    if (_useCloud) {
      try {
        final cloudMap = _prepareToDb(map, forSupabase: true);
        await SupabaseService.client
            .from('inventario_repuestos')
            .upsert(cloudMap);
      } catch (e) {
        debugPrint('Error updating repuesto to Supabase: $e');
      }
    }

    if (kIsWeb) return;

    final db = await database;
    final localMap = _prepareToDb(map, forSupabase: false);
    await db.update('inventario_repuestos', localMap,
        where: 'id = ?', whereArgs: [repuestoToSave.id]);
  }

  Future<Repuesto?> ajustarStock({
    required String repuestoId,
    required int delta,
    String? motivo,
    String? ordenId,
  }) async {
    if (_useCloud) {
      try {
        final repResult = await SupabaseService.client
            .from('inventario_repuestos')
            .select()
            .eq('id', repuestoId)
            .maybeSingle();
        if (repResult == null) return null;

        final rep = Repuesto.fromMap(_prepareFromDb(repResult));
        final nuevoStock = rep.stockActual + delta;
        if (nuevoStock < 0) return null;

        final updated = rep.copyWith(stockActual: nuevoStock);
        final cloudMap = _prepareToDb(updated.toMap(), forSupabase: true);
        await SupabaseService.client
            .from('inventario_repuestos')
            .upsert(cloudMap);

        final historial = HistorialStock(
          repuestoId: repuestoId,
          ordenId: ordenId,
          tipoMovimiento:
              delta > 0 ? TipoMovimiento.entrada : TipoMovimiento.salida,
          cantidad: delta.abs(),
          stockAnterior: rep.stockActual,
          stockPosterior: nuevoStock,
          motivo:
              motivo ?? (delta > 0 ? 'Entrada de stock' : 'Salida de stock'),
        );

        final hMap = historial.toMap();
        if (motivo != null && motivo.contains('Ajuste')) {
          hMap['tipo_movimiento'] = TipoMovimiento.ajuste.value;
        }

        final cloudHMap = _prepareToDb(hMap, forSupabase: true);
        await SupabaseService.client.from('historial_stock').insert(cloudHMap);

        if (!kIsWeb) {
          final db = await database;
          await db.update('inventario_repuestos',
              _prepareToDb(updated.toMap(), forSupabase: false),
              where: 'id = ?', whereArgs: [repuestoId]);
          await db.insert(
              'historial_stock', _prepareToDb(hMap, forSupabase: false));
        }

        return updated;
      } catch (e) {
        debugPrint('Error adjusting stock in Supabase: $e');
      }
    }

    if (kIsWeb) return null;

    final db = await database;
    return await db.transaction((txn) async {
      final maps = await txn.query('inventario_repuestos',
          where: 'id = ?', whereArgs: [repuestoId]);
      if (maps.isEmpty) return null;

      final rep = Repuesto.fromMap(_prepareFromDb(maps.first));
      final nuevoStock = rep.stockActual + delta;
      if (nuevoStock < 0) return null;

      final updated = rep.copyWith(stockActual: nuevoStock);
      await txn.update('inventario_repuestos',
          _prepareToDb(updated.toMap(), forSupabase: false),
          where: 'id = ?', whereArgs: [repuestoId]);

      final historial = HistorialStock(
        repuestoId: repuestoId,
        ordenId: ordenId,
        tipoMovimiento:
            delta > 0 ? TipoMovimiento.entrada : TipoMovimiento.salida,
        cantidad: delta.abs(),
        stockAnterior: rep.stockActual,
        stockPosterior: nuevoStock,
        motivo: motivo ?? (delta > 0 ? 'Entrada de stock' : 'Salida de stock'),
      );

      final hMap = historial.toMap();
      if (motivo != null && motivo.contains('Ajuste')) {
        hMap['tipo_movimiento'] = TipoMovimiento.ajuste.value;
      }
      await txn.insert(
          'historial_stock', _prepareToDb(hMap, forSupabase: false));

      return updated;
    });
  }

  Future<void> deleteRepuesto(String id) async {
    final nowStr = DateTime.now().toIso8601String();
    if (_useCloud) {
      try {
        await SupabaseService.client
            .from('inventario_repuestos')
            .update({'activo': false, 'updated_at': nowStr}).eq('id', id);
      } catch (e) {
        debugPrint('Error deleting repuesto in Supabase: $e');
      }
    }

    if (kIsWeb) return;

    final db = await database;
    await db.update('inventario_repuestos', {'activo': 0, 'updated_at': nowStr},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<int> contarStockBajo() async {
    if (_useCloud && kIsWeb) {
      try {
        var query = SupabaseService.client
            .from('inventario_repuestos')
            .select()
            .eq('activo', true);
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        final response = await query;
        final list = (response as List)
            .map((m) => Repuesto.fromMap(_prepareFromDb(m)))
            .toList();
        return list.where((r) => r.stockActual <= r.stockMinimo).length;
      } catch (e) {
        debugPrint('Error counting low stock in Supabase: $e');
      }
    }

    if (kIsWeb) return 0;

    final db = await database;
    final result = activeTallerId != null
        ? await db.rawQuery(
            'SELECT COUNT(*) as count FROM inventario_repuestos WHERE stock_actual <= stock_minimo AND activo = 1 AND taller_id = ?',
            [
                activeTallerId
              ])
        : await db.rawQuery(
            'SELECT COUNT(*) as count FROM inventario_repuestos WHERE stock_actual <= stock_minimo AND activo = 1');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<HistorialStock>> getHistorial(String repuestoId) async {
    if (_useCloud && kIsWeb) {
      try {
        final response = await SupabaseService.client
            .from('historial_stock')
            .select()
            .eq('repuesto_id', repuestoId)
            .order('created_at', ascending: false)
            .limit(50);
        return (response as List)
            .map((m) => HistorialStock.fromMap(_prepareFromDb(m)))
            .toList();
      } catch (e) {
        debugPrint('Error fetching stock history from Supabase: $e');
      }
    }

    if (kIsWeb) return const [];

    final db = await database;
    final maps = await db.query('historial_stock',
        where: 'repuesto_id = ?',
        whereArgs: [repuestoId],
        orderBy: 'created_at DESC',
        limit: 50);
    return maps.map((m) => HistorialStock.fromMap(_prepareFromDb(m))).toList();
  }

  // ──────────────────────────────────────────────
  //  CRUD: Órdenes de Mantenimiento
  // ──────────────────────────────────────────────

  Future<void> insertOrden(OrdenMantenimiento orden) async {
    final ordenToSave = orden.tallerId == null && activeTallerId != null
        ? orden.copyWith(tallerId: activeTallerId)
        : orden;
    final map = ordenToSave.toMap();
    if (_useCloud) {
      try {
        final cloudMap = _prepareToDb(map, forSupabase: true);
        await SupabaseService.client
            .from('ordenes_mantenimiento')
            .upsert(cloudMap);
      } catch (e) {
        if (e is PostgrestException &&
            e.message.toLowerCase().contains('fecha_ingreso')) {
          try {
            final fallbackMap = _prepareToDb(map, forSupabase: true);
            if (fallbackMap.containsKey('fecha_ingreso')) {
              fallbackMap['created_at'] = fallbackMap['fecha_ingreso'];
              fallbackMap.remove('fecha_ingreso');
            }
            await SupabaseService.client
                .from('ordenes_mantenimiento')
                .upsert(fallbackMap);
          } catch (innerErr) {
            debugPrint('Error inserting fallback orden to Supabase: $innerErr');
          }
        } else {
          debugPrint('Error inserting orden to Supabase: $e');
        }
      }
    }

    if (kIsWeb) return;

    final db = await database;
    final localMap = _prepareToDb(map, forSupabase: false);
    await db.insert('ordenes_mantenimiento', localMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Órdenes ya cerradas (entregadas o canceladas), de la más reciente a la
  /// más antigua. Es el historial del taller: permite consultar trabajos
  /// anteriores de una moto y reimprimir facturas.
  /// Página del historial de órdenes cerradas, de la más reciente a la más
  /// antigua. Se pagina para que un taller con miles de órdenes no cargue
  /// todo de golpe: la pantalla pide de a [limite] y va sumando con
  /// [desplazamiento].
  Future<List<OrdenMantenimiento>> getHistorialOrdenes({
    int limite = 50,
    int desplazamiento = 0,
  }) async {
    List<OrdenMantenimiento> ordenar(List<OrdenMantenimiento> list) {
      list.sort((a, b) => (b.fechaEntrega ?? b.fechaIngreso)
          .compareTo(a.fechaEntrega ?? a.fechaIngreso));
      return list;
    }

    const cerradas = ['ENTREGADA', 'Entregada', 'CANCELADA', 'Cancelada'];

    if (_useCloud && kIsWeb) {
      try {
        var query = SupabaseService.client
            .from('ordenes_mantenimiento')
            .select()
            .inFilter('estado', cerradas);
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        // No se ordena ni se recorta en el servidor: el esquema de la nube no
        // tiene las mismas columnas que espera la app (ver migracion_esquema_nube.sql).
        // Hasta que se alineen, el orden y el corte se hacen en memoria.
        final response = await query;
        final todas = ordenar((response as List)
            .map((m) => OrdenMantenimiento.fromMap(_prepareFromDb(m)))
            .toList());
        return todas.skip(desplazamiento).take(limite).toList();
      } catch (e) {
        debugPrint('Error fetching order history from Supabase: $e');
      }
    }

    if (kIsWeb) return const [];

    if (activeTallerId == null) return [];

    final db = await database;
    final maps = await db.query(
      'ordenes_mantenimiento',
      where:
          "estado IN ('ENTREGADA', 'Entregada', 'CANCELADA', 'Cancelada') AND taller_id = ?",
      whereArgs: [activeTallerId],
      orderBy: 'fecha_ingreso DESC',
      limit: limite,
      offset: desplazamiento,
    );
    return ordenar(maps
        .map((m) => OrdenMantenimiento.fromMap(_prepareFromDb(m)))
        .toList());
  }

  /// Todos los vehículos del taller. Se usa para resolver la moto de cada
  /// orden sin consultar la base una vez por tarjeta.
  Future<List<Vehiculo>> getVehiculos() async {
    if (_useCloud && kIsWeb) {
      try {
        var query = SupabaseService.client
            .from('vehiculos')
            .select()
            .eq('activo', true);
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        final response = await query;
        return (response as List)
            .map((m) => Vehiculo.fromMap(_prepareFromDb(m)))
            .toList();
      } catch (e) {
        debugPrint('Error fetching vehiculos from Supabase: $e');
      }
    }

    if (kIsWeb) return const [];

    final db = await database;
    final maps = activeTallerId != null
        ? await db.query('vehiculos',
            where: 'activo = 1 AND taller_id = ?', whereArgs: [activeTallerId])
        : await db.query('vehiculos', where: 'activo = 1');
    return maps.map((m) => Vehiculo.fromMap(_prepareFromDb(m))).toList();
  }

  Future<List<OrdenMantenimiento>> getOrdenesActivas() async {
    if (_useCloud && kIsWeb) {
      try {
        var query = SupabaseService.client
            .from('ordenes_mantenimiento')
            .select()
            .neq('estado', 'ENTREGADA')
            .neq('estado', 'Entregada')
            .neq('estado', 'CANCELADA')
            .neq('estado', 'Cancelada');
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        final response = await query;
        final list = (response as List)
            .map((m) => OrdenMantenimiento.fromMap(_prepareFromDb(m)))
            .toList();
        list.sort((a, b) => b.fechaIngreso.compareTo(a.fechaIngreso));
        return list;
      } catch (e) {
        debugPrint('Error fetching active orders from Supabase: $e');
      }
    }

    if (kIsWeb) return const [];

    if (activeTallerId == null) return [];

    final db = await database;
    final maps = await db.query('ordenes_mantenimiento',
        where:
            "estado NOT IN ('ENTREGADA', 'Entregada', 'CANCELADA', 'Cancelada') AND taller_id = ?",
        whereArgs: [activeTallerId],
        orderBy: 'fecha_ingreso DESC');
    return maps
        .map((m) => OrdenMantenimiento.fromMap(_prepareFromDb(m)))
        .toList();
  }

  Future<OrdenMantenimiento?> getOrden(String id) async {
    if (_useCloud && kIsWeb) {
      try {
        var query = SupabaseService.client
            .from('ordenes_mantenimiento')
            .select()
            .eq('id', id);
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        final response = await query.maybeSingle();
        if (response != null) {
          return OrdenMantenimiento.fromMap(_prepareFromDb(response));
        }
      } catch (e) {
        debugPrint('Error fetching orden from Supabase: $e');
      }
    }

    if (kIsWeb) return null;

    final db = await database;
    final maps = activeTallerId != null
        ? await db.query('ordenes_mantenimiento',
            where: 'id = ? AND taller_id = ?', whereArgs: [id, activeTallerId])
        : await db
            .query('ordenes_mantenimiento', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return OrdenMantenimiento.fromMap(_prepareFromDb(maps.first));
  }

  Future<void> updateOrden(OrdenMantenimiento orden) async {
    final ordenToSave = orden.tallerId == null && activeTallerId != null
        ? orden.copyWith(tallerId: activeTallerId)
        : orden;
    final map = ordenToSave.toMap();

    // ── PASO 1: SQLite local — escritura SINCRONA e inmediata ─────────────────
    // El estado queda persistido localmente ANTES de intentar la nube.
    // Garantiza que la UI no revierta aunque Supabase demore o falle.
    // Este paso nunca falla por problemas de red.
    if (!kIsWeb) {
      final db = await database;
      final localMap = _prepareToDb(map, forSupabase: false);
      await db.update('ordenes_mantenimiento', localMap,
          where: 'id = ?', whereArgs: [ordenToSave.id]);
    }

    // ── PASO 2: Supabase — dual-write en background (no revierte si falla) ──
    // Si la nube falla, solo se registra una advertencia.
    // El estado ya está seguro en SQLite; se reintentará en la próxima sync.
    if (_useCloud) {
      try {
        final cloudMap = _prepareToDb(map, forSupabase: true);
        await SupabaseService.client
            .from('ordenes_mantenimiento')
            .upsert(cloudMap);
      } catch (e) {
        if (e is PostgrestException &&
            e.message.toLowerCase().contains('fecha_ingreso')) {
          try {
            final fallbackMap = _prepareToDb(map, forSupabase: true);
            if (fallbackMap.containsKey('fecha_ingreso')) {
              fallbackMap['created_at'] = fallbackMap['fecha_ingreso'];
              fallbackMap.remove('fecha_ingreso');
            }
            await SupabaseService.client
                .from('ordenes_mantenimiento')
                .upsert(fallbackMap);
          } catch (innerErr) {
            debugPrint(
                'WARNING dual-write orden Supabase (fecha_ingreso fallback): $innerErr');
          }
        } else {
          debugPrint('WARNING dual-write orden Supabase: $e');
        }
        // NO rethrow — SQLite ya fue actualizado. La nube se reintentará
        // en la siguiente sincronización completa.
      }
    }
  }

  /// Convierte una cotización en una orden de trabajo activa descontando el stock correspondiente.
  Future<void> convertirCotizacionEnOrden(String ordenId) async {
    final orden = await getOrden(ordenId);
    if (orden == null || !orden.esCotizacion) return;

    final items = await getItemsDeOrden(ordenId);

    // Descontar stock e insertar en el historial de stock para cada repuesto
    for (final item in items) {
      await ajustarStock(
        repuestoId: item.repuestoId,
        delta: -item.cantidad,
        motivo: 'Consumido al aprobar Cotización #${orden.numeroOrden}',
        ordenId: ordenId,
      );
    }

    // Cambiar flag de cotización a false
    final updated = orden.copyWith(esCotizacion: false);
    await updateOrden(updated);
  }

  /// Crea en la nube el repuesto ficticio de mano de obra o de repuesto
  /// externo si aún no existe. `orden_items.repuesto_id` tiene llave foránea
  /// contra `inventario_repuestos`: sin esta fila, la inserción del ítem falla
  /// y el detalle de la orden nunca sale del teléfono.
  Future<void> _asegurarRepuestoEspecialEnNube(String repuestoId) async {
    final datos = ReglasOrden.especiales[repuestoId];
    if (datos == null || !SupabaseService.isConfigured) return;

    try {
      final existente = await SupabaseService.client
          .from('inventario_repuestos')
          .select('id')
          .eq('id', repuestoId)
          .maybeSingle();
      if (existente != null) return;

      final ficticio = Repuesto(
        id: repuestoId,
        nombre: datos.nombre,
        codigoInterno: datos.codigo,
        precioCosto: 0.0,
        precioVenta: 0.0,
        stockActual: 999999,
        stockMinimo: 0,
        categoria: CategoriaRepuesto.otros,
        tallerId: activeTallerId,
      );
      await SupabaseService.client
          .from('inventario_repuestos')
          .upsert(_prepareToDb(ficticio.toMap(), forSupabase: true));
    } catch (e) {
      debugPrint('No se pudo asegurar el repuesto especial en la nube: $e');
    }
  }

  Future<bool> agregarItemAOrden({
    required String ordenId,
    required String repuestoId,
    required int cantidad,
    required double precioUnitario,
    required String descripcion,
  }) async {
    // Pre-construir el OrdenItem que se insertará en todos los paths
    final item = OrdenItem(
      ordenId: ordenId,
      repuestoId: repuestoId,
      descripcion: descripcion,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
    );

    // ─── CLOUD PATH ────────────────────────────────────────────────────────────
    // Se intenta primero. Si falla, cae al path SQLite local (offline resilience).
    if (SupabaseService.isConfigured) {
      try {
        await _asegurarRepuestoEspecialEnNube(repuestoId);

        // 1. Verificar flag cotización
        final ordenResult = await SupabaseService.client
            .from('ordenes_mantenimiento')
            .select()
            .eq('id', ordenId)
            .maybeSingle();
        final esCoti = ordenResult != null &&
            (ordenResult['es_cotizacion'] == true ||
                ordenResult['es_cotizacion'] == 1);

        // 2. Obtener repuesto: Supabase primero, SQLite como fallback si no sincronizó aún
        Repuesto? rep;
        final repCloudResult = await SupabaseService.client
            .from('inventario_repuestos')
            .select()
            .eq('id', repuestoId)
            .maybeSingle();
        if (repCloudResult != null) {
          rep = Repuesto.fromMap(_prepareFromDb(repCloudResult));
        } else if (!kIsWeb) {
          // Repuesto aún no sincronizado en Supabase → usar SQLite local como respaldo
          final db = await database;
          final localRep = await db.query('inventario_repuestos',
              where: 'id = ?', whereArgs: [repuestoId]);
          if (localRep.isNotEmpty) {
            rep = Repuesto.fromMap(_prepareFromDb(localRep.first));
          }
        }

        // 3. Actualizar stock — SE PERMITE STOCK NEGATIVO (resiliencia offline)
        // El mecánico puede registrar el consumo aunque el stock local no esté
        // sincronizado. La reconciliación ocurre en la próxima sync completa.
        if (!esCoti && rep != null) {
          final nuevoStock = rep.stockActual - cantidad;
          final updatedRep = rep.copyWith(stockActual: nuevoStock);
          try {
            await SupabaseService.client
                .from('inventario_repuestos')
                .upsert(_prepareToDb(updatedRep.toMap(), forSupabase: true));
          } catch (stockErr) {
            debugPrint('WARNING stock update nube: $stockErr');
          }
          final historial = HistorialStock(
            repuestoId: repuestoId,
            ordenId: ordenId,
            tipoMovimiento: TipoMovimiento.salida,
            cantidad: cantidad,
            stockAnterior: rep.stockActual,
            stockPosterior: nuevoStock,
            motivo: 'Consumido en Orden de Mantenimiento',
          );
          try {
            await SupabaseService.client
                .from('historial_stock')
                .insert(_prepareToDb(historial.toMap(), forSupabase: true));
          } catch (histErr) {
            debugPrint('WARNING historial_stock insert: $histErr');
          }
        }

        // 4. Insertar ítem en Supabase — dual-write obligatorio
        await SupabaseService.client
            .from('orden_items')
            .upsert(_prepareToDb(item.toMap(), forSupabase: true));

        // 5. Recalcular subtotal y actualizar orden en Supabase
        double subtotalRepuestos = 0.0;
        try {
          final itemsResult = await SupabaseService.client
              .from('orden_items')
              .select()
              .eq('orden_id', ordenId);
          // Por `ReglasOrden`, que es la única fuente de verdad: excluye la
          // mano de obra (se acumula en `costo_mano_obra`) y **aplica el
          // descuento**. Calculado a mano aquí se ignoraba, así que un repuesto
          // rebajado inflaba el total de la orden aunque su línea dijera otra
          // cosa.
          subtotalRepuestos = ReglasOrden.subtotalRepuestosCrudo(
            (itemsResult as List)
                .map((m) => Map<String, Object?>.from(m as Map)),
          );
          if (ordenResult != null) {
            final orden =
                OrdenMantenimiento.fromMap(_prepareFromDb(ordenResult));
            final updatedOrden =
                orden.copyWith(subtotalRepuestos: subtotalRepuestos);
            await SupabaseService.client
                .from('ordenes_mantenimiento')
                .upsert(_prepareToDb(updatedOrden.toMap(), forSupabase: true));
          }
        } catch (subErr) {
          debugPrint('WARNING recalculo subtotal orden: $subErr');
        }

        // 6. Dual-write a SQLite local
        if (!kIsWeb) {
          final db = await database;
          if (!esCoti && rep != null) {
            final nuevoStock = rep.stockActual - cantidad;
            await db.update(
              'inventario_repuestos',
              _prepareToDb(rep.copyWith(stockActual: nuevoStock).toMap(),
                  forSupabase: false),
              where: 'id = ?',
              whereArgs: [repuestoId],
            );
            final historial = HistorialStock(
              repuestoId: repuestoId,
              ordenId: ordenId,
              tipoMovimiento: TipoMovimiento.salida,
              cantidad: cantidad,
              stockAnterior: rep.stockActual,
              stockPosterior: rep.stockActual - cantidad,
              motivo: 'Consumido en Orden de Mantenimiento',
            );
            await db.insert('historial_stock',
                _prepareToDb(historial.toMap(), forSupabase: false));
          }
          await db.insert(
            'orden_items',
            _prepareToDb(item.toMap(), forSupabase: false),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          final oResult = await db.query('ordenes_mantenimiento',
              where: 'id = ?', whereArgs: [ordenId]);
          if (oResult.isNotEmpty) {
            final o = OrdenMantenimiento.fromMap(_prepareFromDb(oResult.first));
            await db.update(
              'ordenes_mantenimiento',
              _prepareToDb(
                  o.copyWith(subtotalRepuestos: subtotalRepuestos).toMap(),
                  forSupabase: false),
              where: 'id = ?',
              whereArgs: [ordenId],
            );
          }
        }

        return true;
      } catch (e) {
        debugPrint(
            'WARNING cloud path agregarItemAOrden: $e — usando SQLite local');
        // Cae al path SQLite para garantizar persistencia local
      }
    }

    // En web sin nube no hay dónde guardar: se informa el fallo en vez de
    // fingir que se guardó en una lista que muere al recargar.
    if (kIsWeb) return false;

    // ─── SQLITE-ONLY PATH (offline / sesión no establecida) ──────────────────
    // Siempre persiste el ítem localmente. El stock puede quedar negativo de forma
    // temporal; se reconcilia cuando se restaure la conexión y se sincronice.
    final db = await database;
    return await db.transaction((txn) async {
      final ordenQuery = await txn.query('ordenes_mantenimiento',
          where: 'id = ?', whereArgs: [ordenId]);
      final esCoti = ordenQuery.isNotEmpty &&
          (ordenQuery.first['es_cotizacion'] == 1 ||
              ordenQuery.first['es_cotizacion'] == true);

      // Actualizar stock si el repuesto existe localmente (sin bloqueo negativo)
      if (!esCoti) {
        final repOption = await txn.query('inventario_repuestos',
            where: 'id = ?', whereArgs: [repuestoId]);
        if (repOption.isNotEmpty) {
          final rep = Repuesto.fromMap(_prepareFromDb(repOption.first));
          final nuevoStock = rep.stockActual - cantidad;
          // SIN validación nuevoStock < 0 — permitido para resiliencia offline
          await txn.update(
            'inventario_repuestos',
            _prepareToDb(rep.copyWith(stockActual: nuevoStock).toMap(),
                forSupabase: false),
            where: 'id = ?',
            whereArgs: [repuestoId],
          );
          final historial = HistorialStock(
            repuestoId: repuestoId,
            ordenId: ordenId,
            tipoMovimiento: TipoMovimiento.salida,
            cantidad: cantidad,
            stockAnterior: rep.stockActual,
            stockPosterior: nuevoStock,
            motivo: 'Consumido en Orden de Mantenimiento',
          );
          await txn.insert('historial_stock',
              _prepareToDb(historial.toMap(), forSupabase: false));
        }
        // Si el repuesto no está en SQLite aún (sync pendiente), se omite el
        // descuento de stock pero el ítem SE REGISTRA igualmente.
      }

      await txn.insert(
        'orden_items',
        _prepareToDb(item.toMap(), forSupabase: false),
      );

      final itemsQuery = await txn
          .query('orden_items', where: 'orden_id = ?', whereArgs: [ordenId]);
      // Mismo cálculo que en la ruta de la nube, y por el mismo sitio: si las
      // dos rutas no dan lo mismo, el total cambia según haya internet o no.
      final subtotalRepuestos = ReglasOrden.subtotalRepuestosCrudo(itemsQuery);
      if (ordenQuery.isNotEmpty) {
        final orden =
            OrdenMantenimiento.fromMap(_prepareFromDb(ordenQuery.first));
        final updatedOrden =
            orden.copyWith(subtotalRepuestos: subtotalRepuestos);
        await txn.update(
          'ordenes_mantenimiento',
          _prepareToDb(updatedOrden.toMap(), forSupabase: false),
          where: 'id = ?',
          whereArgs: [ordenId],
        );
      }

      return true;
    });
  }

  /// Agrega un ítem libre (no inventariado) a la orden, creando un repuesto genérico si es necesario.
  Future<bool> agregarItemLibreAOrden({
    required String ordenId,
    required String nombre,
    required double precio,
    required int cantidad,
  }) async {
    const String repuestoGenericoId = ReglasOrden.idRepuestoExterno;

    // 1. Asegurar que existe el repuesto genérico en SQLite local.
    //    En web no hay SQLite: se trabaja con las listas en memoria y abrir la
    //    base local lanzaría una excepción.
    if (!kIsWeb) {
      final db = await database;
      final repResult = await db.query('inventario_repuestos',
          where: 'id = ?', whereArgs: [repuestoGenericoId]);
      if (repResult.isEmpty) {
        final repuestoFantasma = Repuesto(
          id: repuestoGenericoId,
          nombre: 'Repuesto Externo General',
          codigoInterno: 'EXT-001',
          precioCosto: 0.0,
          precioVenta: 0.0, // El precio real se pone en el orden_item
          stockActual: 9999,
          stockMinimo: 0,
          categoria: CategoriaRepuesto.otros,
          tallerId: activeTallerId ?? 'local',
        );
        await db.insert('inventario_repuestos',
            _prepareToDb(repuestoFantasma.toMap(), forSupabase: false),
            conflictAlgorithm: ConflictAlgorithm.ignore);

        // Nunca se hace `upsert` a ciegas: los dos repuestos del sistema no
        // pertenecen a ningún taller (su `taller_id` es nulo) y un upsert los
        // reclamaría como propios, dejándolos invisibles para los demás
        // talleres — que es justo el bug que impedía registrar mano de obra en
        // otras cuentas. `_asegurarRepuestoEspecialEnNube` comprueba primero y
        // solo crea si de verdad falta.
        await _asegurarRepuestoEspecialEnNube(repuestoGenericoId);
      }
    }

    // 2. Reutilizar agregarItemAOrden pasándole el ID genérico y los datos customizados
    return await agregarItemAOrden(
      ordenId: ordenId,
      repuestoId: repuestoGenericoId,
      cantidad: cantidad,
      precioUnitario: precio,
      descripcion: nombre,
    );
  }

  /// Elimina un ítem específico de una orden, restaurando stock si era un repuesto de inventario,
  /// o recalculando el costoManoObra si era mano de obra.
  Future<bool> eliminarItemDeOrden({
    required String itemId,
    required String ordenId,
  }) async {
    // Si usamos Supabase (cloud), intentar eliminar ahí primero
    if (_useCloud) {
      try {
        // Obtener el item antes de eliminarlo
        final itemResponse = await SupabaseService.client
            .from('orden_items')
            .select()
            .eq('id', itemId)
            .maybeSingle();

        if (itemResponse != null) {
          final item = OrdenItem.fromMap(_prepareFromDb(itemResponse));

          // Eliminar de Supabase
          await SupabaseService.client
              .from('orden_items')
              .delete()
              .eq('id', itemId);

          // Si era mano de obra, recalcular costoManoObra
          if (ReglasOrden.esManoObra(item)) {
            final ordenResponse = await SupabaseService.client
                .from('ordenes_mantenimiento')
                .select()
                .eq('id', ordenId)
                .maybeSingle();
            if (ordenResponse != null) {
              final orden =
                  OrdenMantenimiento.fromMap(_prepareFromDb(ordenResponse));
              final nuevoCosto = (orden.costoManoObra - item.precioUnitario)
                  .clamp(0.0, double.infinity);
              final updated = orden.copyWith(costoManoObra: nuevoCosto);
              await SupabaseService.client
                  .from('ordenes_mantenimiento')
                  .upsert(_prepareToDb(updated.toMap(), forSupabase: true));
            }
          } else if (!ReglasOrden.esEspecial(item.repuestoId)) {
            // Restaurar stock para repuestos de inventario (no externos)
            final repResponse = await SupabaseService.client
                .from('inventario_repuestos')
                .select()
                .eq('id', item.repuestoId)
                .maybeSingle();
            if (repResponse != null) {
              final rep = Repuesto.fromMap(_prepareFromDb(repResponse));
              final nuevoStock = rep.stockActual + item.cantidad;
              await SupabaseService.client.from('inventario_repuestos').upsert(
                    _prepareToDb(rep.copyWith(stockActual: nuevoStock).toMap(),
                        forSupabase: true),
                  );
            }
          }

          // Recalcular subtotalRepuestos
          final itemsResponse = await SupabaseService.client
              .from('orden_items')
              .select()
              .eq('orden_id', ordenId);
          final subtotalRepuestos = ReglasOrden.subtotalRepuestosCrudo(
            (itemsResponse as List)
                .map((m) => Map<String, Object?>.from(m as Map)),
          );
          final ordenResponse2 = await SupabaseService.client
              .from('ordenes_mantenimiento')
              .select()
              .eq('id', ordenId)
              .maybeSingle();
          if (ordenResponse2 != null) {
            final orden =
                OrdenMantenimiento.fromMap(_prepareFromDb(ordenResponse2));
            final updated =
                orden.copyWith(subtotalRepuestos: subtotalRepuestos);
            await SupabaseService.client
                .from('ordenes_mantenimiento')
                .upsert(_prepareToDb(updated.toMap(), forSupabase: true));
          }
        }
      } catch (e) {
        debugPrint('Error eliminando item de orden en Supabase: $e');
      }
    }

    // Ahora manejar la DB local (SQLite). En web no existe.
    if (kIsWeb) return true;
    final db = await database;
    return await db.transaction((txn) async {
      // Obtener el item antes de borrarlo
      final itemQuery =
          await txn.query('orden_items', where: 'id = ?', whereArgs: [itemId]);
      if (itemQuery.isEmpty) return false;

      final item = OrdenItem.fromMap(_prepareFromDb(itemQuery.first));

      // Borrar el item
      await txn.delete('orden_items', where: 'id = ?', whereArgs: [itemId]);

      // Si era mano de obra, recalcular costoManoObra
      if (item.repuestoId == ReglasOrden.idManoObra) {
        final ordenQuery = await txn.query('ordenes_mantenimiento',
            where: 'id = ?', whereArgs: [ordenId]);
        if (ordenQuery.isNotEmpty) {
          final orden =
              OrdenMantenimiento.fromMap(_prepareFromDb(ordenQuery.first));
          final nuevoCosto = (orden.costoManoObra - item.precioUnitario)
              .clamp(0.0, double.infinity);
          final updated = orden.copyWith(costoManoObra: nuevoCosto);
          await txn.update('ordenes_mantenimiento',
              _prepareToDb(updated.toMap(), forSupabase: false),
              where: 'id = ?', whereArgs: [ordenId]);
        }
      } else if (!ReglasOrden.esEspecial(item.repuestoId)) {
        // Restaurar stock para repuestos de inventario
        final repQuery = await txn.query('inventario_repuestos',
            where: 'id = ?', whereArgs: [item.repuestoId]);
        if (repQuery.isNotEmpty) {
          final rep = Repuesto.fromMap(_prepareFromDb(repQuery.first));
          final nuevoStock = rep.stockActual + item.cantidad;
          await txn.update(
            'inventario_repuestos',
            _prepareToDb(rep.copyWith(stockActual: nuevoStock).toMap(),
                forSupabase: false),
            where: 'id = ?',
            whereArgs: [item.repuestoId],
          );
        }
      }

      // Recalcular subtotalRepuestos de la orden (excluyendo mano de obra)
      final itemsQuery = await txn
          .query('orden_items', where: 'orden_id = ?', whereArgs: [ordenId]);
      final subtotalRepuestos = ReglasOrden.subtotalRepuestosCrudo(itemsQuery);

      final ordenQuery = await txn.query('ordenes_mantenimiento',
          where: 'id = ?', whereArgs: [ordenId]);
      if (ordenQuery.isNotEmpty) {
        final orden =
            OrdenMantenimiento.fromMap(_prepareFromDb(ordenQuery.first));
        final updated = orden.copyWith(subtotalRepuestos: subtotalRepuestos);
        await txn.update('ordenes_mantenimiento',
            _prepareToDb(updated.toMap(), forSupabase: false),
            where: 'id = ?', whereArgs: [ordenId]);
      }

      return true;
    });
  }

  Future<List<OrdenItem>> getItemsDeOrden(String ordenId) async {
    if (_useCloud && kIsWeb) {
      try {
        final response = await SupabaseService.client
            .from('orden_items')
            .select()
            .eq('orden_id', ordenId);
        return (response as List)
            .map((m) => OrdenItem.fromMap(_prepareFromDb(m)))
            .toList();
      } catch (e) {
        debugPrint('Error fetching order items from Supabase: $e');
      }
    }

    if (kIsWeb) return const [];

    final db = await database;
    final maps = await db
        .query('orden_items', where: 'orden_id = ?', whereArgs: [ordenId]);
    return maps.map((m) => OrdenItem.fromMap(_prepareFromDb(m))).toList();
  }

  Future<void> agregarManoObraAOrden(
      String ordenId, double monto, String concepto) async {
    const String repuestoManoObraId = ReglasOrden.idManoObra;

    // 1. Asegurar que existe el repuesto genérico de mano de obra.
    //    En web no hay SQLite: se trabaja con las listas en memoria, así que
    //    ni siquiera se debe abrir la base local.
    if (!kIsWeb) {
      final db = await database;
      final repResult = await db.query('inventario_repuestos',
          where: 'id = ?', whereArgs: [repuestoManoObraId]);
      if (repResult.isEmpty) {
        final repuestoFantasma = Repuesto(
          id: repuestoManoObraId,
          nombre: 'Mano de Obra (Generada)',
          codigoInterno: 'MO-001',
          precioCosto: 0.0,
          precioVenta: 0.0,
          stockActual: 9999,
          stockMinimo: 0,
          categoria: CategoriaRepuesto.otros,
          tallerId: activeTallerId ?? 'local',
        );
        await db.insert('inventario_repuestos',
            _prepareToDb(repuestoFantasma.toMap(), forSupabase: false),
            conflictAlgorithm: ConflictAlgorithm.ignore);
        // Nunca se hace `upsert` a ciegas: los dos repuestos del sistema no
        // pertenecen a ningún taller (su `taller_id` es nulo) y un upsert los
        // reclamaría como propios, dejándolos invisibles para los demás
        // talleres — que es justo el bug que impedía registrar mano de obra en
        // otras cuentas. `_asegurarRepuestoEspecialEnNube` comprueba primero y
        // solo crea si de verdad falta.
        await _asegurarRepuestoEspecialEnNube(repuestoManoObraId);
      }
    }

    // 2. Crear el item de orden para que salga detallado
    final nuevoItem = OrdenItem(
      ordenId: ordenId,
      repuestoId: repuestoManoObraId,
      descripcion: concepto,
      cantidad: 1,
      precioUnitario: monto,
    );

    if (_useCloud) {
      try {
        await SupabaseService.client
            .from('orden_items')
            .insert(_prepareToDb(nuevoItem.toMap(), forSupabase: true));
        final response = await SupabaseService.client
            .from('ordenes_mantenimiento')
            .select()
            .eq('id', ordenId)
            .maybeSingle();
        if (response != null) {
          final orden = OrdenMantenimiento.fromMap(_prepareFromDb(response));
          final updated =
              orden.copyWith(costoManoObra: orden.costoManoObra + monto);
          await SupabaseService.client
              .from('ordenes_mantenimiento')
              .upsert(_prepareToDb(updated.toMap(), forSupabase: true));

          if (!kIsWeb) {
            final db = await database;
            await db.insert('orden_items',
                _prepareToDb(nuevoItem.toMap(), forSupabase: false));
            await db.update('ordenes_mantenimiento',
                _prepareToDb(updated.toMap(), forSupabase: false),
                where: 'id = ?', whereArgs: [ordenId]);
          }
          return;
        }
      } catch (e) {
        debugPrint('Error adding labor to order in Supabase: $e');
      }
    }

    // En web sin nube no hay dónde guardar: no se finge que se guardó.
    if (kIsWeb) return;

    final dbTrans = await database;
    await dbTrans.transaction((txn) async {
      // Guardar el concepto como item para que salga detallado en la factura,
      // igual que en el modo nube.
      await txn.insert(
          'orden_items', _prepareToDb(nuevoItem.toMap(), forSupabase: false));

      final maps = await txn.query('ordenes_mantenimiento',
          where: 'id = ?', whereArgs: [ordenId]);
      if (maps.isNotEmpty) {
        final orden = OrdenMantenimiento.fromMap(_prepareFromDb(maps.first));
        // El concepto ya quedó guardado como item de la orden; el diagnóstico
        // se reserva para lo que escribe el mecánico.
        final updated =
            orden.copyWith(costoManoObra: orden.costoManoObra + monto);
        await txn.update('ordenes_mantenimiento',
            _prepareToDb(updated.toMap(), forSupabase: false),
            where: 'id = ?', whereArgs: [ordenId]);
      }
    });
  }

  Future<void> editarOrdenMantenimiento(
    String id, {
    String? mecanico,
    String? tipoServicio,
    int? kilometraje,
    String? descripcion,
  }) async {
    Future<void> updateLocal(OrdenMantenimiento orden) async {
      final updated = orden.copyWith(
        mecanicoAsignado: mecanico ?? orden.mecanicoAsignado,
        tipoServicio: tipoServicio ?? orden.tipoServicio,
        kilometrajeIngreso: kilometraje ?? orden.kilometrajeIngreso,
        descripcionProblema: descripcion ?? orden.descripcionProblema,
      );
      // En web no hay SQLite: la base local solo se abre fuera del navegador.
      if (kIsWeb) return;
      final db = await database;
      await db.update('ordenes_mantenimiento',
          _prepareToDb(updated.toMap(), forSupabase: false),
          where: 'id = ?', whereArgs: [id]);
    }

    if (_useCloud) {
      try {
        final response = await SupabaseService.client
            .from('ordenes_mantenimiento')
            .select()
            .eq('id', id)
            .maybeSingle();
        if (response != null) {
          final orden = OrdenMantenimiento.fromMap(_prepareFromDb(response));
          final updated = orden.copyWith(
            mecanicoAsignado: mecanico ?? orden.mecanicoAsignado,
            tipoServicio: tipoServicio ?? orden.tipoServicio,
            kilometrajeIngreso: kilometraje ?? orden.kilometrajeIngreso,
            descripcionProblema: descripcion ?? orden.descripcionProblema,
          );
          await SupabaseService.client
              .from('ordenes_mantenimiento')
              .upsert(_prepareToDb(updated.toMap(), forSupabase: true));
          await updateLocal(orden);
          return;
        }
      } catch (e) {
        debugPrint('Error editarOrdenMantenimiento Supabase: $e');
      }
    }

    if (kIsWeb) return;

    final db = await database;
    final maps = await db
        .query('ordenes_mantenimiento', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      await updateLocal(OrdenMantenimiento.fromMap(_prepareFromDb(maps.first)));
    }
  }

  /// Formato normal de folio: `OT-` y hasta seis dígitos.
  ///
  /// Los folios de emergencia (`OT-<marca de tiempo>`, 13 dígitos) quedan fuera
  /// a propósito: son válidos como identificador, pero no deben mandar sobre la
  /// numeración. Ver [siguienteFolio].
  static final RegExp _formatoFolio = RegExp(r'^OT-(\d{1,6})$');

  /// Siguiente folio a partir de los que ya existen.
  ///
  /// Dos cosas que antes se hacían mal:
  ///
  ///  · Se tomaba la orden **creada más recientemente** y se le sumaba uno. Si
  ///    llegaba una orden vieja después (una subida del rescate, o dos equipos
  ///    con la hora distinta), el folio se repetía y la orden no se creaba.
  ///    Ahora se usa el número más alto, no el más nuevo.
  ///  · Un folio de emergencia con marca de tiempo (`OT-1754...`) entraba en el
  ///    cálculo y envenenaba la serie: a partir de ahí todos los folios pasaban
  ///    a tener trece dígitos. Ahora se ignoran.
  ///
  /// La consulta que lo alimenta está limitada por RLS al taller de la sesión,
  /// que es justo el ámbito del índice único `(taller_id, numero_orden)`.
  static String siguienteFolio(Iterable<Object?> foliosExistentes) {
    var maximo = 0;
    for (final folio in foliosExistentes) {
      if (folio is! String) continue;
      final match = _formatoFolio.firstMatch(folio.trim());
      if (match == null) continue;
      final valor = int.tryParse(match.group(1)!) ?? 0;
      if (valor > maximo) maximo = valor;
    }
    return 'OT-${(maximo + 1).toString().padLeft(5, '0')}';
  }

  /// Genera el siguiente número de orden.
  ///
  /// Se consulta la nube aunque `_useCloud` sea false: ese getter comprueba
  /// `currentUser` en tiempo de ejecución y puede dar false en una instalación
  /// limpia con la sesión ya activa.
  Future<String> generarSiguienteNumeroOrden() async {
    if (SupabaseService.isConfigured) {
      try {
        final res = await SupabaseService.client
            .from('ordenes_mantenimiento')
            .select('numero_orden')
            .limit(20000);
        return siguienteFolio(
            (res as List).map((m) => (m as Map)['numero_orden']));
      } catch (e) {
        debugPrint('WARNING folio desde la nube, se usa marca de tiempo: $e');
        // Sin internet: folio irrepetible. No entra en el cálculo posterior.
        return 'OT-${DateTime.now().millisecondsSinceEpoch}';
      }
    }

    if (!kIsWeb) {
      try {
        final db = await database;
        final result =
            await db.rawQuery('SELECT numero_orden FROM ordenes_mantenimiento');
        return siguienteFolio(result.map((m) => m['numero_orden']));
      } catch (e) {
        debugPrint('WARNING folio desde SQLite: $e');
      }
    }

    return 'OT-00001';
  }

  // ── Operaciones del Módulo Contable (registro_caja) ──

  Future<void> insertRegistroCaja(RegistroCaja registro) async {
    final recordToSave = registro.tallerId == null && activeTallerId != null
        ? registro.copyWith(tallerId: activeTallerId)
        : registro;
    final map = recordToSave.toMap();
    if (_useCloud) {
      try {
        final cloudMap = _prepareToDb(map, forSupabase: true);
        await SupabaseService.client.from('registro_caja').upsert(cloudMap);
      } catch (e) {
        debugPrint('Error inserting registro_caja to Supabase: $e');
      }
    }

    if (kIsWeb) return;

    final db = await database;
    final localMap = _prepareToDb(map, forSupabase: false);
    await db.insert('registro_caja', localMap,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<RegistroCaja>> getRegistrosCaja() async {
    if (_useCloud && kIsWeb) {
      try {
        var query = SupabaseService.client.from('registro_caja').select();
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        final res = await query.order('fecha', ascending: false);
        return (res as List)
            .map((map) => RegistroCaja.fromMap(_prepareFromDb(map)))
            .toList();
      } catch (e) {
        debugPrint('Error getting registro_caja from Supabase: $e');
      }
    }

    if (kIsWeb) return const [];

    final db = await database;
    final List<Map<String, dynamic>> maps = activeTallerId != null
        ? await db.query('registro_caja',
            where: 'taller_id = ?',
            whereArgs: [activeTallerId],
            orderBy: 'fecha DESC')
        : await db.query('registro_caja', orderBy: 'fecha DESC');

    return maps
        .map((map) => RegistroCaja.fromMap(_prepareFromDb(map)))
        .toList();
  }

  Future<RegistroCaja?> getRegistroCajaPorReferenciaYTipo(
      String referenciaId, String tipo) async {
    if (_useCloud) {
      try {
        var query = SupabaseService.client.from('registro_caja').select();
        query = query.eq('referencia_id', referenciaId).eq('tipo', tipo);
        if (activeTallerId != null) {
          query = query.eq('taller_id', activeTallerId!);
        }
        final res = await query.maybeSingle();
        if (res != null) {
          return RegistroCaja.fromMap(_prepareFromDb(res));
        }
      } catch (e) {
        debugPrint('Error query single registro_caja from Supabase: $e');
      }
    }

    if (kIsWeb) return null;

    final db = await database;
    final List<Map<String, dynamic>> maps = activeTallerId != null
        ? await db.query('registro_caja',
            where: 'referencia_id = ? AND tipo = ? AND taller_id = ?',
            whereArgs: [referenciaId, tipo, activeTallerId],
            limit: 1)
        : await db.query('registro_caja',
            where: 'referencia_id = ? AND tipo = ?',
            whereArgs: [referenciaId, tipo],
            limit: 1);

    if (maps.isNotEmpty) {
      return RegistroCaja.fromMap(_prepareFromDb(maps.first));
    }
    return null;
  }

  Future<void> editarRegistroCaja(
      String id, double monto, String concepto, String tipo) async {
    Future<void> updateLocal(RegistroCaja reg) async {
      final updated =
          reg.copyWith(monto: monto, concepto: concepto, tipo: tipo);
      // En web no hay SQLite: la base local solo se abre fuera del navegador.
      if (kIsWeb) return;
      final db = await database;
      await db.update(
          'registro_caja', _prepareToDb(updated.toMap(), forSupabase: false),
          where: 'id = ?', whereArgs: [id]);
    }

    if (_useCloud) {
      try {
        final response = await SupabaseService.client
            .from('registro_caja')
            .select()
            .eq('id', id)
            .maybeSingle();
        if (response != null) {
          final reg = RegistroCaja.fromMap(_prepareFromDb(response));
          final updated =
              reg.copyWith(monto: monto, concepto: concepto, tipo: tipo);
          await SupabaseService.client
              .from('registro_caja')
              .upsert(_prepareToDb(updated.toMap(), forSupabase: true));
          await updateLocal(reg);
          return;
        }
      } catch (e) {
        debugPrint('Error editarRegistroCaja Supabase: $e');
      }
    }

    if (kIsWeb) return;

    final db = await database;
    final maps =
        await db.query('registro_caja', where: 'id = ?', whereArgs: [id]);
    if (maps.isNotEmpty) {
      await updateLocal(RegistroCaja.fromMap(_prepareFromDb(maps.first)));
    }
  }

  // ──────────────────────────────────────────────
  //  Datos de demostración (Seed Data)
  // ──────────────────────────────────────────────

  // ──────────────────────────────────────────────
  //  Operaciones de Cuentas por Cobrar y Abonos
  // ──────────────────────────────────────────────

  Future<void> insertarAbono(Abono abono) async {
    if (!kIsWeb) {
      final db = await database;
      await db.insert('orden_abonos', abono.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }

    if (_useCloud) {
      try {
        await SupabaseService.client
            .from('orden_abonos')
            .upsert(abono.toMap(), onConflict: 'id');
      } catch (e) {
        debugPrint('[DatabaseHelper] Error upserting abono en Supabase: $e');
      }
    }
  }

  Future<List<Abono>> obtenerAbonosDeOrden(String ordenId) async {
    // En web no existe SQLite: abrir la base aquí lanzaba y mataba el método
    // antes de poder leer nada. Misma familia de bugs que `getItemsDeOrden`.
    if (kIsWeb) {
      if (_useCloud) {
        try {
          final res = await SupabaseService.client
              .from('orden_abonos')
              .select()
              .eq('orden_id', ordenId)
              .order('created_at', ascending: true);
          return (res as List)
              .map((m) => Abono.fromMap(Map<String, dynamic>.from(m as Map)))
              .toList();
        } catch (e) {
          debugPrint('Error obteniendo abonos de Supabase: $e');
        }
      }
      return const [];
    }

    // En el teléfono la fuente sigue siendo SQLite: es la única que hoy tiene
    // los abonos completos. Cambiarla por la nube los haría desaparecer de la
    // pantalla mientras el rescate no se haya ejecutado.
    final db = await database;
    final res = await db.query(
      'orden_abonos',
      where: 'orden_id = ?',
      whereArgs: [ordenId],
      orderBy: 'created_at ASC',
    );
    return res.map((m) => Abono.fromMap(m)).toList();
  }

  Future<void> actualizarPagoOrden({
    required String ordenId,
    required double montoPagado,
    required double saldoPendiente,
    required String estadoPago,
  }) async {
    final data = {
      'monto_pagado': montoPagado,
      'saldo_pendiente': saldoPendiente,
      'estado_pago': estadoPago,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (!kIsWeb) {
      final db = await database;
      await db.update('ordenes_mantenimiento', data,
          where: 'id = ?', whereArgs: [ordenId]);
    }

    if (_useCloud) {
      try {
        await SupabaseService.client
            .from('ordenes_mantenimiento')
            .update(data)
            .eq('id', ordenId);
      } catch (e) {
        debugPrint(
            '[DatabaseHelper] Error actualizando pago de orden en Supabase: $e');
      }
    }
  }
}
