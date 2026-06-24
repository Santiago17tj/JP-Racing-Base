import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/repuesto.dart';
import '../models/historial_stock.dart';
import '../models/cliente.dart';
import '../models/vehiculo.dart';
import '../models/orden_mantenimiento.dart';
import '../models/orden_item.dart';
import '../../core/constants/enums.dart';

/// Singleton para operaciones CRUD sobre la Base de Datos.
///
/// Implementa una estrategia híbrida:
/// - En dispositivos móviles (Android/iOS): Usa SQLite real (`sqflite`).
/// - En Web: Utiliza una base de datos simulada en memoria para evitar errores
///   con WebAssembly/Service Workers (`sqflite_sw.js`) en servidores locales.
class DatabaseHelper {
  DatabaseHelper._() {
    if (kIsWeb) {
      _initWebSeedData();
    }
  }
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  // --- Listas en memoria para simulación Web ---
  final List<Map<String, dynamic>> _webClientes = [];
  final List<Map<String, dynamic>> _webVehiculos = [];
  final List<Map<String, dynamic>> _webRepuestos = [];
  final List<Map<String, dynamic>> _webOrdenes = [];
  final List<Map<String, dynamic>> _webOrdenItems = [];
  final List<Map<String, dynamic>> _webHistorial = [];

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('SQLite no está inicializado en web. Usando simulación en memoria.');
    }
    _database ??= await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'moto_taller.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla: clientes
    await db.execute('''
      CREATE TABLE clientes (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        apellido TEXT NOT NULL,
        tipo_documento TEXT NOT NULL,
        numero_documento TEXT NOT NULL UNIQUE,
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

    // Tabla: vehiculos
    await db.execute('''
      CREATE TABLE vehiculos (
        id TEXT PRIMARY KEY,
        cliente_id TEXT NOT NULL,
        placa_patente TEXT NOT NULL UNIQUE,
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

    // Tabla: inventario_repuestos
    await db.execute('''
      CREATE TABLE inventario_repuestos (
        id TEXT PRIMARY KEY,
        codigo_interno TEXT NOT NULL UNIQUE,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        foto_url TEXT,
        categoria TEXT NOT NULL,
        subcategoria TEXT,
        marca_repuesto TEXT,
        numero_parte TEXT,
        stock_actual INTEGER NOT NULL DEFAULT 0 CHECK(stock_actual >= 0),
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

    // Tabla: ordenes_mantenimiento
    await db.execute('''
      CREATE TABLE ordenes_mantenimiento (
        id TEXT PRIMARY KEY,
        numero_orden TEXT NOT NULL UNIQUE,
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
        fecha_ingreso TEXT NOT NULL,
        fecha_promesa TEXT,
        fecha_entrega TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (cliente_id) REFERENCES clientes(id),
        FOREIGN KEY (vehiculo_id) REFERENCES vehiculos(id)
      )
    ''');

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
    await db.execute('CREATE INDEX idx_repuestos_categoria ON inventario_repuestos(categoria)');
    await db.execute('CREATE INDEX idx_repuestos_nombre ON inventario_repuestos(nombre)');
    await db.execute('CREATE INDEX idx_historial_repuesto ON historial_stock(repuesto_id, created_at DESC)');
    await db.execute('CREATE INDEX idx_ordenes_estado ON ordenes_mantenimiento(estado)');
    await db.execute('CREATE INDEX idx_ordenes_cliente ON ordenes_mantenimiento(cliente_id)');
    await db.execute('CREATE INDEX idx_orden_items_orden ON orden_items(orden_id)');

    // Inserción de semillas en móvil
    await _insertMobileSeedData(db);
  }

  // ──────────────────────────────────────────────
  //  CRUD: Clientes
  // ──────────────────────────────────────────────

  Future<void> insertCliente(Cliente cliente) async {
    if (kIsWeb) {
      _webClientes.removeWhere((c) => c['id'] == cliente.id);
      _webClientes.add(cliente.toMap());
      return;
    }
    final db = await database;
    await db.insert('clientes', cliente.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Cliente>> getClientes() async {
    if (kIsWeb) {
      final list = _webClientes
          .where((c) => c['activo'] == 1)
          .map((m) => Cliente.fromMap(m))
          .toList();
      list.sort((a, b) => a.nombre.compareTo(b.nombre));
      return list;
    }
    final db = await database;
    final maps = await db.query('clientes', where: 'activo = 1', orderBy: 'nombre ASC');
    return maps.map((m) => Cliente.fromMap(m)).toList();
  }

  Future<Cliente?> getCliente(String id) async {
    if (kIsWeb) {
      final matches = _webClientes.where((c) => c['id'] == id);
      if (matches.isEmpty) return null;
      return Cliente.fromMap(matches.first);
    }
    final db = await database;
    final maps = await db.query('clientes', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Cliente.fromMap(maps.first);
  }

  // ──────────────────────────────────────────────
  //  CRUD: Vehículos
  // ──────────────────────────────────────────────

  Future<void> insertVehiculo(Vehiculo vehiculo) async {
    if (kIsWeb) {
      _webVehiculos.removeWhere((v) => v['id'] == vehiculo.id);
      _webVehiculos.add(vehiculo.toMap());
      return;
    }
    final db = await database;
    await db.insert('vehiculos', vehiculo.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Vehiculo>> getVehiculosPorCliente(String clienteId) async {
    if (kIsWeb) {
      return _webVehiculos
          .where((v) => v['cliente_id'] == clienteId && v['activo'] == 1)
          .map((m) => Vehiculo.fromMap(m))
          .toList();
    }
    final db = await database;
    final maps = await db.query('vehiculos', where: 'cliente_id = ? AND activo = 1', whereArgs: [clienteId]);
    return maps.map((m) => Vehiculo.fromMap(m)).toList();
  }

  Future<Vehiculo?> getVehiculo(String id) async {
    if (kIsWeb) {
      final matches = _webVehiculos.where((v) => v['id'] == id);
      if (matches.isEmpty) return null;
      return Vehiculo.fromMap(matches.first);
    }
    final db = await database;
    final maps = await db.query('vehiculos', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Vehiculo.fromMap(maps.first);
  }

  // ──────────────────────────────────────────────
  //  CRUD: Repuestos
  // ──────────────────────────────────────────────

  Future<void> insertRepuesto(Repuesto repuesto) async {
    if (kIsWeb) {
      _webRepuestos.removeWhere((r) => r['id'] == repuesto.id);
      _webRepuestos.add(repuesto.toMap());
      return;
    }
    final db = await database;
    await db.insert('inventario_repuestos', repuesto.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Repuesto>> getRepuestos({
    String? busqueda,
    String? categoria,
    bool soloStockBajo = false,
  }) async {
    if (kIsWeb) {
      var filtered = _webRepuestos.where((r) => r['activo'] == 1);
      if (busqueda != null && busqueda.isNotEmpty) {
        final query = busqueda.toLowerCase();
        filtered = filtered.where((r) =>
            (r['nombre'] as String).toLowerCase().contains(query) ||
            (r['codigo_interno'] as String).toLowerCase().contains(query));
      }
      if (categoria != null) {
        filtered = filtered.where((r) => r['categoria'] == categoria);
      }
      if (soloStockBajo) {
        filtered = filtered.where((r) => (r['stock_actual'] as int) <= (r['stock_minimo'] as int));
      }

      final list = filtered.map((m) => Repuesto.fromMap(m)).toList();
      list.sort((a, b) => a.nombre.compareTo(b.nombre));
      return list;
    }

    final db = await database;
    final where = <String>['activo = 1'];
    final args = <dynamic>[];

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

    final maps = await db.query('inventario_repuestos', where: where.join(' AND '), whereArgs: args, orderBy: 'nombre ASC');
    return maps.map((m) => Repuesto.fromMap(m)).toList();
  }

  Future<Repuesto?> getRepuestoPorCodigo(String codigoInterno) async {
    if (kIsWeb) {
      final matches = _webRepuestos.where((r) =>
          (r['codigo_interno'] as String).toUpperCase() == codigoInterno.toUpperCase() &&
          r['activo'] == 1);
      if (matches.isEmpty) return null;
      return Repuesto.fromMap(matches.first);
    }
    final db = await database;
    final maps = await db.query('inventario_repuestos', where: 'codigo_interno = ? AND activo = 1', whereArgs: [codigoInterno], limit: 1);
    if (maps.isEmpty) return null;
    return Repuesto.fromMap(maps.first);
  }

  Future<void> updateRepuesto(Repuesto repuesto) async {
    if (kIsWeb) {
      final idx = _webRepuestos.indexWhere((r) => r['id'] == repuesto.id);
      if (idx != -1) {
        _webRepuestos[idx] = repuesto.toMap();
      }
      return;
    }
    final db = await database;
    await db.update('inventario_repuestos', repuesto.toMap(), where: 'id = ?', whereArgs: [repuesto.id]);
  }

  Future<Repuesto?> ajustarStock({
    required String repuestoId,
    required int delta,
    String? motivo,
    String? ordenId,
  }) async {
    if (kIsWeb) {
      final idx = _webRepuestos.indexWhere((r) => r['id'] == repuestoId);
      if (idx == -1) return null;

      final repMap = _webRepuestos[idx];
      final repuesto = Repuesto.fromMap(repMap);
      final nuevoStock = repuesto.stockActual + delta;

      if (nuevoStock < 0) return null; // Evitar stock negativo

      final updatedRepuesto = repuesto.copyWith(stockActual: nuevoStock);
      _webRepuestos[idx] = updatedRepuesto.toMap();

      // Registrar historial de stock
      final historial = HistorialStock(
        repuestoId: repuestoId,
        ordenId: ordenId,
        tipoMovimiento: delta > 0 ? TipoMovimiento.entrada : TipoMovimiento.salida,
        cantidad: delta.abs(),
        stockAnterior: repuesto.stockActual,
        stockPosterior: nuevoStock,
        motivo: motivo ?? (delta > 0 ? 'Entrada de stock' : 'Salida de stock'),
      );
      
      final hMap = historial.toMap();
      if (motivo != null && motivo.contains('Ajuste')) {
        hMap['tipo_movimiento'] = TipoMovimiento.ajuste.value;
      }
      _webHistorial.add(hMap);

      return updatedRepuesto;
    }

    final db = await database;
    return await db.transaction((txn) async {
      final maps = await txn.query('inventario_repuestos', where: 'id = ?', whereArgs: [repuestoId]);
      if (maps.isEmpty) return null;

      final rep = Repuesto.fromMap(maps.first);
      final nuevoStock = rep.stockActual + delta;
      if (nuevoStock < 0) return null;

      final updated = rep.copyWith(stockActual: nuevoStock);
      await txn.update('inventario_repuestos', updated.toMap(), where: 'id = ?', whereArgs: [repuestoId]);

      final historial = HistorialStock(
        repuestoId: repuestoId,
        ordenId: ordenId,
        tipoMovimiento: delta > 0 ? TipoMovimiento.entrada : TipoMovimiento.salida,
        cantidad: delta.abs(),
        stockAnterior: rep.stockActual,
        stockPosterior: nuevoStock,
        motivo: motivo ?? (delta > 0 ? 'Entrada de stock' : 'Salida de stock'),
      );
      
      final hMap = historial.toMap();
      if (motivo != null && motivo.contains('Ajuste')) {
        hMap['tipo_movimiento'] = TipoMovimiento.ajuste.value;
      }
      await txn.insert('historial_stock', hMap);

      return updated;
    });
  }

  Future<void> deleteRepuesto(String id) async {
    if (kIsWeb) {
      final idx = _webRepuestos.indexWhere((r) => r['id'] == id);
      if (idx != -1) {
        _webRepuestos[idx]['activo'] = 0;
        _webRepuestos[idx]['updated_at'] = DateTime.now().toIso8601String();
      }
      return;
    }
    final db = await database;
    await db.update('inventario_repuestos', {'activo': 0, 'updated_at': DateTime.now().toIso8601String()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<int> contarStockBajo() async {
    if (kIsWeb) {
      return _webRepuestos
          .where((r) => r['activo'] == 1 && (r['stock_actual'] as int) <= (r['stock_minimo'] as int))
          .length;
    }
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM inventario_repuestos WHERE stock_actual <= stock_minimo AND activo = 1');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<List<HistorialStock>> getHistorial(String repuestoId) async {
    if (kIsWeb) {
      final matches = _webHistorial
          .where((h) => h['repuesto_id'] == repuestoId)
          .map((m) => HistorialStock.fromMap(m))
          .toList();
      matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return matches.take(50).toList();
    }
    final db = await database;
    final maps = await db.query('historial_stock', where: 'repuesto_id = ?', whereArgs: [repuestoId], orderBy: 'created_at DESC', limit: 50);
    return maps.map((m) => HistorialStock.fromMap(m)).toList();
  }

  // ──────────────────────────────────────────────
  //  CRUD: Órdenes de Mantenimiento
  // ──────────────────────────────────────────────

  Future<void> insertOrden(OrdenMantenimiento orden) async {
    if (kIsWeb) {
      _webOrdenes.removeWhere((o) => o['id'] == orden.id);
      _webOrdenes.add(orden.toMap());
      return;
    }
    final db = await database;
    await db.insert('ordenes_mantenimiento', orden.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<OrdenMantenimiento>> getOrdenesActivas() async {
    if (kIsWeb) {
      final actives = _webOrdenes
          .where((o) => o['estado'] != 'ENTREGADA' && o['estado'] != 'CANCELADA')
          .map((m) => OrdenMantenimiento.fromMap(m))
          .toList();
      actives.sort((a, b) => b.fechaIngreso.compareTo(a.fechaIngreso));
      return actives;
    }
    final db = await database;
    final maps = await db.query('ordenes_mantenimiento', where: "estado NOT IN ('ENTREGADA', 'CANCELADA')", orderBy: 'fecha_ingreso DESC');
    return maps.map((m) => OrdenMantenimiento.fromMap(m)).toList();
  }

  Future<OrdenMantenimiento?> getOrden(String id) async {
    if (kIsWeb) {
      final matches = _webOrdenes.where((o) => o['id'] == id);
      if (matches.isEmpty) return null;
      return OrdenMantenimiento.fromMap(matches.first);
    }
    final db = await database;
    final maps = await db.query('ordenes_mantenimiento', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return OrdenMantenimiento.fromMap(maps.first);
  }

  Future<void> updateOrden(OrdenMantenimiento orden) async {
    if (kIsWeb) {
      final idx = _webOrdenes.indexWhere((o) => o['id'] == orden.id);
      if (idx != -1) {
        _webOrdenes[idx] = orden.toMap();
      }
      return;
    }
    final db = await database;
    await db.update('ordenes_mantenimiento', orden.toMap(), where: 'id = ?', whereArgs: [orden.id]);
  }

  Future<bool> agregarItemAOrden({
    required String ordenId,
    required String repuestoId,
    required int cantidad,
    required double precioUnitario,
    required String descripcion,
  }) async {
    if (kIsWeb) {
      // 1. Ajustar el stock en memoria
      final idx = _webRepuestos.indexWhere((r) => r['id'] == repuestoId);
      if (idx == -1) return false;

      final repMap = _webRepuestos[idx];
      final rep = Repuesto.fromMap(repMap);
      final nuevoStock = rep.stockActual - cantidad;
      if (nuevoStock < 0) return false; // Stock insuficiente

      // Actualizar stock del repuesto en memoria
      _webRepuestos[idx] = rep.copyWith(stockActual: nuevoStock).toMap();

      // Registrar historial de stock
      final historial = HistorialStock(
        repuestoId: repuestoId,
        ordenId: ordenId,
        tipoMovimiento: TipoMovimiento.salida,
        cantidad: cantidad,
        stockAnterior: rep.stockActual,
        stockPosterior: nuevoStock,
        motivo: 'Consumido en Orden de Mantenimiento',
      );
      _webHistorial.add(historial.toMap());

      // 2. Insertar en items en memoria
      final item = OrdenItem(
        ordenId: ordenId,
        repuestoId: repuestoId,
        descripcion: descripcion,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
      );
      _webOrdenItems.add(item.toMap());

      // 3. Recalcular subtotales de la orden en memoria
      final subtotalRepuestos = _webOrdenItems
          .where((i) => i['orden_id'] == ordenId)
          .fold(0.0, (sum, i) => sum + (i['subtotal'] as num).toDouble());

      final oIdx = _webOrdenes.indexWhere((o) => o['id'] == ordenId);
      if (oIdx != -1) {
        final orden = OrdenMantenimiento.fromMap(_webOrdenes[oIdx]);
        _webOrdenes[oIdx] = orden.copyWith(subtotalRepuestos: subtotalRepuestos).toMap();
      }

      return true;
    }

    final db = await database;
    return await db.transaction((txn) async {
      final repOption = await txn.query('inventario_repuestos', where: 'id = ?', whereArgs: [repuestoId]);
      if (repOption.isEmpty) return false;

      final rep = Repuesto.fromMap(repOption.first);
      final nuevoStock = rep.stockActual - cantidad;
      if (nuevoStock < 0) return false;

      await txn.update('inventario_repuestos', rep.copyWith(stockActual: nuevoStock).toMap(), where: 'id = ?', whereArgs: [repuestoId]);

      final historial = HistorialStock(
        repuestoId: repuestoId,
        ordenId: ordenId,
        tipoMovimiento: TipoMovimiento.salida,
        cantidad: cantidad,
        stockAnterior: rep.stockActual,
        stockPosterior: nuevoStock,
        motivo: 'Consumido en Orden de Mantenimiento',
      );
      await txn.insert('historial_stock', historial.toMap());

      final item = OrdenItem(
        ordenId: ordenId,
        repuestoId: repuestoId,
        descripcion: descripcion,
        cantidad: cantidad,
        precioUnitario: precioUnitario,
      );
      await txn.insert('orden_items', item.toMap());

      final itemsQuery = await txn.query('orden_items', where: 'orden_id = ?', whereArgs: [ordenId]);
      double subtotalRepuestos = 0.0;
      for (final m in itemsQuery) {
        subtotalRepuestos += (m['subtotal'] as num).toDouble();
      }

      final ordenQuery = await txn.query('ordenes_mantenimiento', where: 'id = ?', whereArgs: [ordenId]);
      if (ordenQuery.isNotEmpty) {
        final orden = OrdenMantenimiento.fromMap(ordenQuery.first);
        final updatedOrden = orden.copyWith(subtotalRepuestos: subtotalRepuestos);
        await txn.update('ordenes_mantenimiento', updatedOrden.toMap(), where: 'id = ?', whereArgs: [ordenId]);
      }

      return true;
    });
  }

  Future<List<OrdenItem>> getItemsDeOrden(String ordenId) async {
    if (kIsWeb) {
      return _webOrdenItems
          .where((i) => i['orden_id'] == ordenId)
          .map((m) => OrdenItem.fromMap(m))
          .toList();
    }
    final db = await database;
    final maps = await db.query('orden_items', where: 'orden_id = ?', whereArgs: [ordenId]);
    return maps.map((m) => OrdenItem.fromMap(m)).toList();
  }

  Future<void> agregarManoObraAOrden(String ordenId, double monto, String concepto) async {
    if (kIsWeb) {
      final oIdx = _webOrdenes.indexWhere((o) => o['id'] == ordenId);
      if (oIdx != -1) {
        final orden = OrdenMantenimiento.fromMap(_webOrdenes[oIdx]);
        final nuevoCosto = orden.costoManoObra + monto;
        
        String? diagActual = orden.diagnostico;
        String nuevoConcepto = '- Mano de obra: $concepto (\$${monto.toStringAsFixed(2)})';
        String diagActualizado = diagActual == null || diagActual.isEmpty
            ? nuevoConcepto
            : '$diagActual\n$nuevoConcepto';

        _webOrdenes[oIdx] = orden.copyWith(
          costoManoObra: nuevoCosto,
          diagnostico: diagActualizado,
        ).toMap();
      }
      return;
    }

    final db = await database;
    await db.transaction((txn) async {
      final maps = await txn.query('ordenes_mantenimiento', where: 'id = ?', whereArgs: [ordenId]);
      if (maps.isNotEmpty) {
        final orden = OrdenMantenimiento.fromMap(maps.first);
        final nuevoCosto = orden.costoManoObra + monto;
        
        String? diagnosticoActual = orden.diagnostico;
        String nuevoConceptoText = '- Mano de obra: $concepto (\$${monto.toStringAsFixed(2)})';
        String diagnosticoActualizado = diagnosticoActual == null || diagnosticoActual.isEmpty
            ? nuevoConceptoText
            : '$diagnosticoActual\n$nuevoConceptoText';

        final updated = orden.copyWith(
          costoManoObra: nuevoCosto,
          diagnostico: diagnosticoActualizado,
        );
        await txn.update('ordenes_mantenimiento', updated.toMap(), where: 'id = ?', whereArgs: [ordenId]);
      }
    });
  }

  Future<String> generarSiguienteNumeroOrden() async {
    if (kIsWeb) {
      final count = _webOrdenes.length;
      final index = count + 1;
      return 'OT-${index.toString().padLeft(5, '0')}';
    }
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM ordenes_mantenimiento');
    final count = Sqflite.firstIntValue(result) ?? 0;
    final index = count + 1;
    return 'OT-${index.toString().padLeft(5, '0')}';
  }

  // ──────────────────────────────────────────────
  //  Datos de demostración (Seed Data)
  // ──────────────────────────────────────────────

  Future<void> _insertMobileSeedData(Database db) async {
    final now = DateTime.now().toIso8601String();
    
    // --- Clientes semilla ---
    final clientes = [
      {
        'id': 'c1-uuid',
        'nombre': 'Carlos',
        'apellido': 'Mendoza',
        'tipo_documento': 'DNI',
        'numero_documento': '10293847',
        'email': 'carlos.mendoza@email.com',
        'telefono': '+573004567890',
        'direccion': 'Calle 45 # 12-34',
        'ciudad': 'Bogotá',
        'notas': 'Cliente recurrente, prefiere repuestos Brembo.',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'c2-uuid',
        'nombre': 'María',
        'apellido': 'Rodríguez',
        'tipo_documento': 'CC',
        'numero_documento': '98765432',
        'email': 'maria.rodriguez@email.com',
        'telefono': '+549112345678',
        'direccion': 'Av. Santa Fe 2345',
        'ciudad': 'Buenos Aires',
        'notas': 'Solo WhatsApp.',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      }
    ];

    for (final c in clientes) {
      await db.insert('clientes', c);
    }

    // --- Vehículos semilla ---
    final vehiculos = [
      {
        'id': 'v1-uuid',
        'cliente_id': 'c1-uuid',
        'placa_patente': 'ABC-123',
        'marca': 'Yamaha',
        'modelo': 'MT-09',
        'anio': 2022,
        'kilometraje_actual': 15200,
        'color': 'Negro/Azul',
        'numero_motor': 'M309-102938',
        'numero_chasis': 'JYAR1029384756',
        'notas': 'Tiene rayón en el tanque lado derecho.',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'v2-uuid',
        'cliente_id': 'c2-uuid',
        'placa_patente': 'XYZ-987',
        'marca': 'Honda',
        'modelo': 'CB190R',
        'anio': 2020,
        'kilometraje_actual': 24500,
        'color': 'Rojo Tricolor',
        'numero_motor': 'CB190-837462',
        'numero_chasis': '1HFKB190837462',
        'notas': 'Ninguna.',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      }
    ];

    for (final v in vehiculos) {
      await db.insert('vehiculos', v);
    }

    // --- Repuestos semilla ---
    final seedRepuestos = _obtenerSeedRepuestosList(now);
    for (final r in seedRepuestos) {
      await db.insert('inventario_repuestos', r);
    }

    // --- Órdenes semilla ---
    final deUnaSemana = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final deTresDias = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();

    final ordenes = [
      {
        'id': 'o1-uuid',
        'numero_orden': 'OT-00001',
        'cliente_id': 'c1-uuid',
        'vehiculo_id': 'v1-uuid',
        'estado': 'EN_REPARACION',
        'tipo_servicio': 'MANTENIMIENTO_CORRECTIVO',
        'kilometraje_ingreso': 15200,
        'descripcion_problema': 'Frenos delanteros largos y ruido metálico al frenar.',
        'diagnostico': 'Desgaste severo de las pastillas delanteras. Requiere cambio.',
        'notas_mecanico': 'Verificar también líquido de frenos.',
        'mecanico_asignado': 'Juan Pérez',
        'costo_mano_obra': 15.00,
        'subtotal_repuestos': 0.0,
        'total_estimado': 15.00,
        'fecha_ingreso': deUnaSemana,
        'fecha_promesa': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'created_at': deUnaSemana,
        'updated_at': deUnaSemana,
      },
      {
        'id': 'o2-uuid',
        'numero_orden': 'OT-00002',
        'cliente_id': 'c2-uuid',
        'vehiculo_id': 'v2-uuid',
        'estado': 'INGRESADA',
        'tipo_servicio': 'MANTENIMIENTO_PREVENTIVO',
        'kilometraje_ingreso': 24500,
        'descripcion_problema': 'Cambio de aceite y revisión general de 25,000 km.',
        'diagnostico': '',
        'notas_mecanico': '',
        'mecanico_asignado': 'Sandro Gómez',
        'costo_mano_obra': 0.0,
        'subtotal_repuestos': 0.0,
        'total_estimado': 0.0,
        'fecha_ingreso': deTresDias,
        'fecha_promesa': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'created_at': deTresDias,
        'updated_at': deTresDias,
      }
    ];

    for (final o in ordenes) {
      await db.insert('ordenes_mantenimiento', o);
    }
  }

  void _initWebSeedData() {
    final now = DateTime.now().toIso8601String();
    
    // Clientes
    _webClientes.addAll([
      {
        'id': 'c1-uuid',
        'nombre': 'Carlos',
        'apellido': 'Mendoza',
        'tipo_documento': 'DNI',
        'numero_documento': '10293847',
        'email': 'carlos.mendoza@email.com',
        'telefono': '+573004567890',
        'direccion': 'Calle 45 # 12-34',
        'ciudad': 'Bogotá',
        'notas': 'Cliente recurrente, prefiere repuestos Brembo.',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'c2-uuid',
        'nombre': 'María',
        'apellido': 'Rodríguez',
        'tipo_documento': 'CC',
        'numero_documento': '98765432',
        'email': 'maria.rodriguez@email.com',
        'telefono': '+549112345678',
        'direccion': 'Av. Santa Fe 2345',
        'ciudad': 'Buenos Aires',
        'notas': 'Solo WhatsApp.',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      }
    ]);

    // Vehículos
    _webVehiculos.addAll([
      {
        'id': 'v1-uuid',
        'cliente_id': 'c1-uuid',
        'placa_patente': 'ABC-123',
        'marca': 'Yamaha',
        'modelo': 'MT-09',
        'anio': 2022,
        'kilometraje_actual': 15200,
        'color': 'Negro/Azul',
        'numero_motor': 'M309-102938',
        'numero_chasis': 'JYAR1029384756',
        'notas': 'Tiene rayón en el tanque lado derecho.',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'v2-uuid',
        'cliente_id': 'c2-uuid',
        'placa_patente': 'XYZ-987',
        'marca': 'Honda',
        'modelo': 'CB190R',
        'anio': 2020,
        'kilometraje_actual': 24500,
        'color': 'Rojo Tricolor',
        'numero_motor': 'CB190-837462',
        'numero_chasis': '1HFKB190837462',
        'notas': 'Ninguna.',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      }
    ]);

    // Repuestos
    _webRepuestos.addAll(_obtenerSeedRepuestosList(now));

    // Órdenes
    final deUnaSemana = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
    final deTresDias = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();

    _webOrdenes.addAll([
      {
        'id': 'o1-uuid',
        'numero_orden': 'OT-00001',
        'cliente_id': 'c1-uuid',
        'vehiculo_id': 'v1-uuid',
        'estado': 'EN_REPARACION',
        'tipo_servicio': 'MANTENIMIENTO_CORRECTIVO',
        'kilometraje_ingreso': 15200,
        'descripcion_problema': 'Frenos delanteros largos y ruido metálico al frenar.',
        'diagnostico': 'Desgaste severo de las pastillas delanteras. Requiere cambio.',
        'notas_mecanico': 'Verificar también líquido de frenos.',
        'mecanico_asignado': 'Juan Pérez',
        'costo_mano_obra': 15.00,
        'subtotal_repuestos': 0.0,
        'total_estimado': 15.00,
        'fecha_ingreso': deUnaSemana,
        'fecha_promesa': DateTime.now().add(const Duration(days: 2)).toIso8601String(),
        'created_at': deUnaSemana,
        'updated_at': deUnaSemana,
      },
      {
        'id': 'o2-uuid',
        'numero_orden': 'OT-00002',
        'cliente_id': 'c2-uuid',
        'vehiculo_id': 'v2-uuid',
        'estado': 'INGRESADA',
        'tipo_servicio': 'MANTENIMIENTO_PREVENTIVO',
        'kilometraje_ingreso': 24500,
        'descripcion_problema': 'Cambio de aceite y revisión general de 25,000 km.',
        'diagnostico': '',
        'notas_mecanico': '',
        'mecanico_asignado': 'Sandro Gómez',
        'costo_mano_obra': 0.0,
        'subtotal_repuestos': 0.0,
        'total_estimado': 0.0,
        'fecha_ingreso': deTresDias,
        'fecha_promesa': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
        'created_at': deTresDias,
        'updated_at': deTresDias,
      }
    ]);
  }

  List<Map<String, dynamic>> _obtenerSeedRepuestosList(String now) {
    return [
      {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567801',
        'codigo_interno': 'FRE-001',
        'nombre': 'Pastillas de Freno Delanteras',
        'descripcion': 'Pastillas de freno sinterizadas para uso en calle y pista',
        'categoria': 'FRENOS',
        'marca_repuesto': 'Brembo',
        'numero_parte': 'BP-SX200',
        'stock_actual': 12,
        'stock_minimo': 5,
        'precio_costo': 18.50,
        'precio_venta': 32.00,
        'ubicacion_almacen': 'Estante A-1',
        'unidad_medida': 'par',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567802',
        'codigo_interno': 'FRE-002',
        'nombre': 'Disco de Freno Trasero 220mm',
        'descripcion': 'Disco de freno flotante de acero inoxidable',
        'categoria': 'FRENOS',
        'marca_repuesto': 'EBC',
        'numero_parte': 'DF-220T',
        'stock_actual': 3,
        'stock_minimo': 4,
        'precio_costo': 45.00,
        'precio_venta': 78.50,
        'ubicacion_almacen': 'Estante A-2',
        'unidad_medida': 'unidad',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567803',
        'codigo_interno': 'MOT-001',
        'nombre': 'Filtro de Aceite HF204',
        'descripcion': 'Filtro de aceite de alta calidad para motores 4T',
        'categoria': 'FILTROS',
        'marca_repuesto': 'HiFlo',
        'numero_parte': 'HF204',
        'stock_actual': 25,
        'stock_minimo': 10,
        'precio_costo': 5.20,
        'precio_venta': 12.00,
        'ubicacion_almacen': 'Estante B-1',
        'unidad_medida': 'unidad',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567804',
        'codigo_interno': 'MOT-002',
        'nombre': 'Bujía Iridium CR9EIX',
        'descripcion': 'Bujía de iridio para mejor rendimiento y durabilidad',
        'categoria': 'MOTOR',
        'marca_repuesto': 'NGK',
        'numero_parte': 'CR9EIX',
        'stock_actual': 8,
        'stock_minimo': 10,
        'precio_costo': 9.80,
        'precio_venta': 18.50,
        'ubicacion_almacen': 'Estante B-2',
        'unidad_medida': 'unidad',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567805',
        'codigo_interno': 'ELE-001',
        'nombre': 'Regulador de Voltaje SH847',
        'descripcion': 'Regulador/rectificador de voltaje universal',
        'categoria': 'ELECTRICO',
        'marca_repuesto': 'Shindengen',
        'numero_parte': 'SH847AA',
        'stock_actual': 2,
        'stock_minimo': 3,
        'precio_costo': 32.00,
        'precio_venta': 55.00,
        'ubicacion_almacen': 'Estante C-1',
        'unidad_medida': 'unidad',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567806',
        'codigo_interno': 'LUB-001',
        'nombre': 'Aceite Motor 10W-40 Full Synthetic',
        'descripcion': 'Aceite sintético de alto rendimiento para motocicletas 4T',
        'categoria': 'LUBRICANTES',
        'marca_repuesto': 'Motul',
        'numero_parte': '7100-10W40',
        'stock_actual': 30,
        'stock_minimo': 15,
        'precio_costo': 12.50,
        'precio_venta': 22.00,
        'ubicacion_almacen': 'Estante D-1',
        'unidad_medida': 'litro',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': 'a1b2c3d4-e5f6-7890-abcd-ef1234567807',
        'codigo_interno': 'TRA-001',
        'nombre': 'Kit de Arrastre 428H (14-42)',
        'descripcion': 'Kit completo: cadena DID 428H + piñón 14T + corona 42T',
        'categoria': 'TRANSMISION',
        'marca_repuesto': 'DID',
        'numero_parte': 'KIT-428H-1442',
        'stock_actual': 0,
        'stock_minimo': 3,
        'precio_costo': 38.00,
        'precio_venta': 65.00,
        'ubicacion_almacen': 'Estante E-1',
        'unidad_medida': 'kit',
        'activo': 1,
        'created_at': now,
        'updated_at': now,
      }
    ];
  }
}
