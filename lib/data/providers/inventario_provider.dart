import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/constants/enums.dart';
import '../../core/services/storage_service.dart';
import '../database/database_helper.dart';
import '../models/repuesto.dart';
import '../models/historial_stock.dart';

/// Estado reactivo del módulo de Inventario.
///
/// Centraliza la lógica de negocio: búsqueda, filtros, ajustes de stock
/// y sincronización con SQLite. Notifica a la UI ante cualquier cambio.
class InventarioProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // ── Estado ────────────────────────────────────
  List<Repuesto> _repuestos = [];
  List<Repuesto> get repuestos => _repuestos;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _busqueda = '';
  String get busqueda => _busqueda;

  CategoriaRepuesto? _categoriaFiltro;
  CategoriaRepuesto? get categoriaFiltro => _categoriaFiltro;

  bool _soloStockBajo = false;
  bool get soloStockBajo => _soloStockBajo;

  int _totalStockBajo = 0;
  int get totalStockBajo => _totalStockBajo;

  // ── Estado del escáner ────────────────────────
  Repuesto? _repuestoEscaneado;
  Repuesto? get repuestoEscaneado => _repuestoEscaneado;

  // ── Inicialización ────────────────────────────

  /// Carga inicial de datos desde SQLite.
  Future<void> cargarRepuestos() async {
    _isLoading = true;
    notifyListeners();

    try {
      _repuestos = await _db.getRepuestos(
        busqueda: _busqueda.isEmpty ? null : _busqueda,
        categoria: _categoriaFiltro?.value,
        soloStockBajo: _soloStockBajo,
      );
      _totalStockBajo = await _db.contarStockBajo();
    } catch (e) {
      debugPrint('Error cargando repuestos: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Búsqueda & Filtros ────────────────────────

  /// Actualiza el texto de búsqueda y recarga.
  Future<void> buscar(String texto) async {
    _busqueda = texto;
    await cargarRepuestos();
  }

  /// Aplica o quita el filtro de categoría.
  Future<void> filtrarPorCategoria(CategoriaRepuesto? categoria) async {
    _categoriaFiltro = (_categoriaFiltro == categoria) ? null : categoria;
    await cargarRepuestos();
  }

  /// Alterna el filtro de stock bajo.
  Future<void> toggleStockBajo() async {
    _soloStockBajo = !_soloStockBajo;
    await cargarRepuestos();
  }

  /// Limpia todos los filtros.
  Future<void> limpiarFiltros() async {
    _busqueda = '';
    _categoriaFiltro = null;
    _soloStockBajo = false;
    await cargarRepuestos();
  }

  // ── Acciones Rápidas de Stock ─────────────────

  /// Incrementa stock en 1 unidad (Quick Action +).
  /// Actualiza en memoria de forma optimista antes de la llamada al DB.
  Future<bool> incrementarStock(String repuestoId) async {
    // Actualización optimista: el número cambia en pantalla al instante
    final idx = _repuestos.indexWhere((r) => r.id == repuestoId);
    if (idx != -1) {
      _repuestos[idx] = _repuestos[idx].copyWith(
        stockActual: _repuestos[idx].stockActual + 1,
      );
      _totalStockBajo = _repuestos.where((r) => r.stockBajo).length;
      notifyListeners();
    }

    final result = await _db.ajustarStock(
      repuestoId: repuestoId,
      delta: 1,
      motivo: 'Incremento rápido +1',
    );
    if (result != null) {
      await cargarRepuestos(); // Confirmar con datos reales del DB
      return true;
    }
    // Revertir actualización optimista si el DB falló
    if (idx != -1) {
      _repuestos[idx] = _repuestos[idx].copyWith(
        stockActual: (_repuestos[idx].stockActual - 1).clamp(0, 99999),
      );
      notifyListeners();
    }
    return false;
  }

  /// Decrementa stock en 1 unidad (Quick Action −).
  /// Actualiza en memoria de forma optimista antes de la llamada al DB.
  Future<bool> decrementarStock(String repuestoId) async {
    // Actualización optimista: el número cambia en pantalla al instante
    final idx = _repuestos.indexWhere((r) => r.id == repuestoId);
    if (idx != -1) {
      final nuevoStock = (_repuestos[idx].stockActual - 1).clamp(0, 99999);
      _repuestos[idx] = _repuestos[idx].copyWith(stockActual: nuevoStock);
      _totalStockBajo = _repuestos.where((r) => r.stockBajo).length;
      notifyListeners();
    }

    final result = await _db.ajustarStock(
      repuestoId: repuestoId,
      delta: -1,
      motivo: 'Decremento rápido -1',
    );
    if (result != null) {
      await cargarRepuestos(); // Confirmar con datos reales del DB
      return true;
    }
    // Revertir actualización optimista si el DB falló
    if (idx != -1) {
      _repuestos[idx] = _repuestos[idx].copyWith(
        stockActual: _repuestos[idx].stockActual + 1,
      );
      notifyListeners();
    }
    return false;
  }

  /// Ajuste arbitrario de stock con motivo (entrada o salida con cantidad libre).
  /// Actualiza en memoria de forma optimista antes de la llamada al DB.
  Future<bool> ajustarStock({
    required String repuestoId,
    required int delta,
    String? motivo,
  }) async {
    // Actualización optimista
    final idx = _repuestos.indexWhere((r) => r.id == repuestoId);
    if (idx != -1) {
      final nuevoStock = (_repuestos[idx].stockActual + delta).clamp(0, 99999);
      _repuestos[idx] = _repuestos[idx].copyWith(stockActual: nuevoStock);
      _totalStockBajo = _repuestos.where((r) => r.stockBajo).length;
      notifyListeners();
    }

    final result = await _db.ajustarStock(
      repuestoId: repuestoId,
      delta: delta,
      motivo: motivo,
    );
    if (result != null) {
      await cargarRepuestos();
      return true;
    }
    // Revertir si falló
    if (idx != -1) {
      _repuestos[idx] = _repuestos[idx].copyWith(
        stockActual: (_repuestos[idx].stockActual - delta).clamp(0, 99999),
      );
      notifyListeners();
    }
    return false;
  }

  // ── CRUD ──────────────────────────────────────

  /// Agrega un nuevo repuesto al inventario.
  Future<void> agregarRepuesto(Repuesto repuesto) async {
    await _db.insertRepuesto(repuesto);
    await cargarRepuestos();
    notifyListeners();
  }

  /// Crea un repuesto y opcionalmente sube una foto al storage.
  Future<void> crearRepuestoConFoto({
    required String codigoInterno,
    required String nombre,
    String? descripcion,
    CategoriaRepuesto categoria = CategoriaRepuesto.otros,
    int stockActual = 0,
    int stockMinimo = 5,
    double precioCosto = 0,
    double precioVenta = 0,
    XFile? foto,
  }) async {
    String? fotoUrl;
    if (foto != null) {
      fotoUrl = await StorageService.uploadImage(
        bucket: 'repuestos',
        path: '${DateTime.now().millisecondsSinceEpoch}_${foto.name}',
        image: foto,
      );
    }

    final repuesto = Repuesto(
      codigoInterno: codigoInterno,
      nombre: nombre,
      descripcion: descripcion,
      fotoUrl: fotoUrl,
      categoria: categoria,
      stockActual: stockActual,
      stockMinimo: stockMinimo,
      precioCosto: precioCosto,
      precioVenta: precioVenta,
    );

    await _db.insertRepuesto(repuesto);
    await cargarRepuestos();
  }

  /// Actualiza un repuesto existente.
  Future<void> actualizarRepuesto(Repuesto repuesto) async {
    await _db.updateRepuesto(repuesto);
    await cargarRepuestos();
  }

  /// Elimina (soft delete) un repuesto.
  Future<void> eliminarRepuesto(String id) async {
    await _db.deleteRepuesto(id);
    await cargarRepuestos();
  }

  // ── Escáner ───────────────────────────────────

  /// Busca un repuesto por código interno (simulación de escáner).
  Future<Repuesto?> buscarPorCodigo(String codigo) async {
    _repuestoEscaneado = await _db.getRepuestoPorCodigo(codigo);
    notifyListeners();
    return _repuestoEscaneado;
  }

  /// Limpia el resultado del escáner.
  void limpiarEscaner() {
    _repuestoEscaneado = null;
    notifyListeners();
  }

  // ── Historial ─────────────────────────────────

  /// Obtiene el historial de movimientos de un repuesto.
  Future<List<HistorialStock>> obtenerHistorial(String repuestoId) async {
    return await _db.getHistorial(repuestoId);
  }

  // ── Estadísticas Rápidas ──────────────────────

  /// Total de repuestos activos.
  int get totalRepuestos => _repuestos.length;

  /// Valor total del inventario a precio de venta.
  double get valorInventario => _repuestos.fold(
        0.0,
        (sum, r) => sum + (r.precioVenta * r.stockActual),
      );

  /// Repuestos sin stock.
  int get sinStock => _repuestos.where((r) => r.stockActual == 0).length;

  /// Restablece el inventario a su estado inicial para evitar fugas de datos entre talleres.
  void limpiarDatos() {
    _repuestos = [];
    _isLoading = false;
    _busqueda = '';
    _categoriaFiltro = null;
    _soloStockBajo = false;
    _totalStockBajo = 0;
    _repuestoEscaneado = null;
    notifyListeners();
  }
}
