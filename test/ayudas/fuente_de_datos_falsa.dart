import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/core/dominio/reglas_orden.dart';
import 'package:moto_taller_app/data/database/fuente_de_datos.dart';
import 'package:moto_taller_app/data/models/abono.dart';
import 'package:moto_taller_app/data/models/cliente.dart';
import 'package:moto_taller_app/data/models/historial_stock.dart';
import 'package:moto_taller_app/data/models/orden_item.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/data/models/perfil_taller.dart';
import 'package:moto_taller_app/data/models/registro_caja.dart';
import 'package:moto_taller_app/data/models/repuesto.dart';
import 'package:moto_taller_app/data/models/vehiculo.dart';

/// Base de datos en memoria para las pruebas de pantalla.
///
/// Imita la **ruta de SQLite**, que es la que corre en el teléfono del cliente:
/// mismos efectos secundarios (descontar stock al añadir un repuesto,
/// devolverlo al eliminarlo, acumular la mano de obra en `costoManoObra`) y
/// mismos cálculos, todos por `ReglasOrden`. Si esto duplicara la aritmética a
/// mano, las pruebas pasarían con las cuentas mal — que es exactamente el bug
/// de los cuatro recálculos sin descuento.
///
/// Es lo que fingía ser la ruta de memoria en web que se eliminó el 12/08/2026,
/// pero viviendo en `test/`, que es donde una cosa así tiene sentido.
class FuenteDeDatosFalsa implements FuenteDeDatos {
  final List<Cliente> clientes = [];
  final List<Vehiculo> vehiculos = [];
  final List<Repuesto> repuestos = [];
  final List<OrdenMantenimiento> ordenes = [];
  final List<OrdenItem> items = [];
  final List<RegistroCaja> caja = [];
  final List<Abono> abonos = [];
  final List<HistorialStock> historial = [];
  PerfilTaller? perfil;

  /// Cuántas veces se llamó a cada método. Sirve para comprobar que la pantalla
  /// llega hasta la base y no se queda en el camino.
  final Map<String, int> llamadas = {};

  /// Métodos que deben fallar, para probar el camino del error.
  final Set<String> fallan = {};

  void _registrar(String metodo) {
    llamadas[metodo] = (llamadas[metodo] ?? 0) + 1;
    if (fallan.contains(metodo)) {
      throw StateError('FuenteDeDatosFalsa: $metodo configurado para fallar');
    }
  }

  // ── Ayudas para las pruebas ───────────────────

  OrdenMantenimiento ordenPorId(String id) =>
      ordenes.firstWhere((o) => o.id == id);

  Repuesto repuestoPorId(String id) => repuestos.firstWhere((r) => r.id == id);

  List<OrdenItem> itemsDe(String ordenId) =>
      items.where((i) => i.ordenId == ordenId).toList();

  void _reemplazarOrden(OrdenMantenimiento nueva) {
    final i = ordenes.indexWhere((o) => o.id == nueva.id);
    if (i == -1) {
      ordenes.add(nueva);
    } else {
      ordenes[i] = nueva;
    }
  }

  /// Vuelve a calcular `subtotal_repuestos` de la orden por `ReglasOrden`,
  /// igual que hacen las dos rutas reales tras tocar los ítems.
  void _recalcularSubtotal(String ordenId) {
    final i = ordenes.indexWhere((o) => o.id == ordenId);
    if (i == -1) return;
    ordenes[i] = ordenes[i].copyWith(
      subtotalRepuestos: ReglasOrden.subtotalRepuestos(itemsDe(ordenId)),
    );
  }

  // ── Sincronización ────────────────────────────

  @override
  Future<void> sincronizarDesdeNube(String tallerId) async =>
      _registrar('sincronizarDesdeNube');

  @override
  Future<int> limpiarDatosDeOtrosTalleres(String tallerActivo) async {
    _registrar('limpiarDatosDeOtrosTalleres');
    return 0;
  }

  // ── Perfil del taller ─────────────────────────

  @override
  Future<PerfilTaller> insertPerfilTaller(PerfilTaller taller) async {
    _registrar('insertPerfilTaller');
    perfil = taller;
    return taller;
  }

  @override
  Future<PerfilTaller?> getPerfilTallerLocal(String usuarioId) async {
    _registrar('getPerfilTallerLocal');
    return perfil;
  }

  @override
  Future<void> savePerfilTallerLocal(PerfilTaller taller) async {
    _registrar('savePerfilTallerLocal');
    perfil = taller;
  }

  // ── Clientes ──────────────────────────────────

  @override
  Future<void> insertCliente(Cliente cliente) async {
    _registrar('insertCliente');
    clientes.removeWhere((c) => c.id == cliente.id);
    clientes.add(cliente);
  }

  @override
  Future<List<Cliente>> getClientes() async {
    _registrar('getClientes');
    return List.of(clientes);
  }

  @override
  Future<Cliente?> getCliente(String id) async {
    _registrar('getCliente');
    for (final c in clientes) {
      if (c.id == id) return c;
    }
    return null;
  }

  // ── Vehículos ─────────────────────────────────

  @override
  Future<void> insertVehiculo(Vehiculo vehiculo) async {
    _registrar('insertVehiculo');
    vehiculos.removeWhere((v) => v.id == vehiculo.id);
    vehiculos.add(vehiculo);
  }

  @override
  Future<List<Vehiculo>> getVehiculos() async {
    _registrar('getVehiculos');
    return vehiculos.where((v) => v.activo).toList();
  }

  @override
  Future<List<Vehiculo>> getVehiculosPorCliente(String clienteId) async {
    _registrar('getVehiculosPorCliente');
    return vehiculos
        .where((v) => v.clienteId == clienteId && v.activo)
        .toList();
  }

  @override
  Future<Vehiculo?> getVehiculo(String id) async {
    _registrar('getVehiculo');
    for (final v in vehiculos) {
      if (v.id == id) return v;
    }
    return null;
  }

  // ── Inventario ────────────────────────────────

  @override
  Future<void> insertRepuesto(Repuesto repuesto) async {
    _registrar('insertRepuesto');
    repuestos.removeWhere((r) => r.id == repuesto.id);
    repuestos.add(repuesto);
  }

  @override
  Future<List<Repuesto>> getRepuestos({
    String? busqueda,
    String? categoria,
    bool soloStockBajo = false,
  }) async {
    _registrar('getRepuestos');
    return repuestos.where((r) {
      if (!r.activo) return false;
      if (categoria != null && r.categoria.value != categoria) return false;
      if (soloStockBajo && !r.stockBajo) return false;
      if (busqueda != null && busqueda.isNotEmpty) {
        final q = busqueda.toLowerCase();
        return r.nombre.toLowerCase().contains(q) ||
            r.codigoInterno.toLowerCase().contains(q);
      }
      return true;
    }).toList();
  }

  @override
  Future<Repuesto?> getRepuestoPorCodigo(String codigoInterno) async {
    _registrar('getRepuestoPorCodigo');
    for (final r in repuestos) {
      if (r.codigoInterno == codigoInterno && r.activo) return r;
    }
    return null;
  }

  @override
  Future<void> updateRepuesto(Repuesto repuesto) async {
    _registrar('updateRepuesto');
    final i = repuestos.indexWhere((r) => r.id == repuesto.id);
    if (i != -1) repuestos[i] = repuesto;
  }

  @override
  Future<void> deleteRepuesto(String id) async {
    _registrar('deleteRepuesto');
    final i = repuestos.indexWhere((r) => r.id == id);
    if (i != -1) repuestos[i] = repuestos[i].copyWith(activo: false);
  }

  @override
  Future<int> contarStockBajo() async {
    _registrar('contarStockBajo');
    return repuestos.where((r) => r.activo && r.stockBajo).length;
  }

  @override
  Future<Repuesto?> ajustarStock({
    required String repuestoId,
    required int delta,
    String? motivo,
    String? ordenId,
  }) async {
    _registrar('ajustarStock');
    final i = repuestos.indexWhere((r) => r.id == repuestoId);
    if (i == -1) return null;
    final antes = repuestos[i].stockActual;
    final despues = antes + delta;
    repuestos[i] = repuestos[i].copyWith(stockActual: despues);
    historial.add(HistorialStock(
      repuestoId: repuestoId,
      ordenId: ordenId,
      tipoMovimiento:
          delta >= 0 ? TipoMovimiento.entrada : TipoMovimiento.salida,
      cantidad: delta.abs(),
      stockAnterior: antes,
      stockPosterior: despues,
      motivo: motivo,
    ));
    return repuestos[i];
  }

  @override
  Future<List<HistorialStock>> getHistorial(String repuestoId) async {
    _registrar('getHistorial');
    return historial.where((h) => h.repuestoId == repuestoId).toList();
  }

  // ── Órdenes ───────────────────────────────────

  @override
  Future<void> insertOrden(OrdenMantenimiento orden) async {
    _registrar('insertOrden');
    _reemplazarOrden(orden);
  }

  @override
  Future<List<OrdenMantenimiento>> getOrdenesActivas() async {
    _registrar('getOrdenesActivas');
    final lista = ordenes
        .where((o) =>
            o.estado != EstadoOrden.entregada &&
            o.estado != EstadoOrden.cancelada)
        .toList();
    lista.sort((a, b) => b.fechaIngreso.compareTo(a.fechaIngreso));
    return lista;
  }

  @override
  Future<List<OrdenMantenimiento>> getHistorialOrdenes({
    int limite = 50,
    int desplazamiento = 0,
  }) async {
    _registrar('getHistorialOrdenes');
    final lista = ordenes
        .where((o) =>
            o.estado == EstadoOrden.entregada ||
            o.estado == EstadoOrden.cancelada)
        .toList();
    lista.sort((a, b) => (b.fechaEntrega ?? b.fechaIngreso)
        .compareTo(a.fechaEntrega ?? a.fechaIngreso));
    return lista.skip(desplazamiento).take(limite).toList();
  }

  @override
  Future<OrdenMantenimiento?> getOrden(String id) async {
    _registrar('getOrden');
    for (final o in ordenes) {
      if (o.id == id) return o;
    }
    return null;
  }

  @override
  Future<void> updateOrden(OrdenMantenimiento orden) async {
    _registrar('updateOrden');
    _reemplazarOrden(orden);
  }

  @override
  Future<String> generarSiguienteNumeroOrden() async {
    _registrar('generarSiguienteNumeroOrden');
    return 'OT-${(ordenes.length + 1).toString().padLeft(5, '0')}';
  }

  // ── Ítems de orden ────────────────────────────

  @override
  Future<List<OrdenItem>> getItemsDeOrden(String ordenId) async {
    _registrar('getItemsDeOrden');
    return itemsDe(ordenId);
  }

  @override
  Future<bool> agregarItemAOrden({
    required String ordenId,
    required String repuestoId,
    required int cantidad,
    required double precioUnitario,
    required String descripcion,
  }) async {
    _registrar('agregarItemAOrden');
    items.add(OrdenItem(
      ordenId: ordenId,
      repuestoId: repuestoId,
      descripcion: descripcion,
      cantidad: cantidad,
      precioUnitario: precioUnitario,
    ));

    // Igual que SQLite: descuenta stock salvo en cotizaciones, y sin bloquear
    // el stock negativo (el taller sigue trabajando sin señal).
    final iOrden = ordenes.indexWhere((o) => o.id == ordenId);
    final esCotizacion = iOrden != -1 && ordenes[iOrden].esCotizacion;
    final iRep = repuestos.indexWhere((r) => r.id == repuestoId);
    if (!esCotizacion && iRep != -1) {
      final antes = repuestos[iRep].stockActual;
      repuestos[iRep] = repuestos[iRep].copyWith(stockActual: antes - cantidad);
      historial.add(HistorialStock(
        repuestoId: repuestoId,
        ordenId: ordenId,
        tipoMovimiento: TipoMovimiento.salida,
        cantidad: cantidad,
        stockAnterior: antes,
        stockPosterior: antes - cantidad,
        motivo: 'Consumido en Orden de Mantenimiento',
      ));
    }

    _recalcularSubtotal(ordenId);
    return true;
  }

  @override
  Future<bool> agregarItemLibreAOrden({
    required String ordenId,
    required String nombre,
    required double precio,
    required int cantidad,
  }) async {
    _registrar('agregarItemLibreAOrden');
    items.add(OrdenItem(
      ordenId: ordenId,
      repuestoId: ReglasOrden.idRepuestoExterno,
      descripcion: nombre,
      cantidad: cantidad,
      precioUnitario: precio,
    ));
    _recalcularSubtotal(ordenId);
    return true;
  }

  @override
  Future<bool> eliminarItemDeOrden({
    required String itemId,
    required String ordenId,
  }) async {
    _registrar('eliminarItemDeOrden');
    final i = items.indexWhere((it) => it.id == itemId);
    if (i == -1) return false;
    final item = items.removeAt(i);

    if (ReglasOrden.esManoObraCrudo(item.repuestoId)) {
      final iOrden = ordenes.indexWhere((o) => o.id == ordenId);
      if (iOrden != -1) {
        final nuevo = (ordenes[iOrden].costoManoObra - item.precioUnitario)
            .clamp(0.0, double.infinity);
        ordenes[iOrden] = ordenes[iOrden].copyWith(costoManoObra: nuevo);
      }
    } else if (!ReglasOrden.esEspecial(item.repuestoId)) {
      // Devuelve el stock al inventario, como la base real.
      final iRep = repuestos.indexWhere((r) => r.id == item.repuestoId);
      if (iRep != -1) {
        repuestos[iRep] = repuestos[iRep]
            .copyWith(stockActual: repuestos[iRep].stockActual + item.cantidad);
      }
    }

    _recalcularSubtotal(ordenId);
    return true;
  }

  @override
  Future<void> agregarManoObraAOrden(
      String ordenId, double monto, String concepto) async {
    _registrar('agregarManoObraAOrden');
    // El ítem existe solo para que salga detallado en la factura; el valor
    // que se cobra vive en `orden.costoManoObra`. Sumarlo también al subtotal
    // de repuestos lo cobraría dos veces.
    items.add(OrdenItem(
      ordenId: ordenId,
      repuestoId: ReglasOrden.idManoObra,
      descripcion: concepto,
      cantidad: 1,
      precioUnitario: monto,
    ));
    final i = ordenes.indexWhere((o) => o.id == ordenId);
    if (i != -1) {
      ordenes[i] =
          ordenes[i].copyWith(costoManoObra: ordenes[i].costoManoObra + monto);
    }
  }

  // ── Caja y abonos ─────────────────────────────

  @override
  Future<void> insertRegistroCaja(RegistroCaja registro) async {
    _registrar('insertRegistroCaja');
    caja.add(registro);
  }

  @override
  Future<List<RegistroCaja>> getRegistrosCaja() async {
    _registrar('getRegistrosCaja');
    return List.of(caja);
  }

  @override
  Future<void> editarRegistroCaja(
      String id, double monto, String concepto, String tipo) async {
    _registrar('editarRegistroCaja');
    final i = caja.indexWhere((r) => r.id == id);
    if (i != -1) {
      caja[i] = caja[i].copyWith(monto: monto, concepto: concepto, tipo: tipo);
    }
  }

  @override
  Future<void> insertarAbono(Abono abono) async {
    _registrar('insertarAbono');
    abonos.add(abono);
  }

  @override
  Future<List<Abono>> obtenerAbonosDeOrden(String ordenId) async {
    _registrar('obtenerAbonosDeOrden');
    return abonos.where((a) => a.ordenId == ordenId).toList();
  }

  @override
  Future<void> actualizarPagoOrden({
    required String ordenId,
    required double montoPagado,
    required double saldoPendiente,
    required String estadoPago,
  }) async {
    _registrar('actualizarPagoOrden');
    final i = ordenes.indexWhere((o) => o.id == ordenId);
    if (i != -1) {
      ordenes[i] = ordenes[i].copyWith(
        montoPagado: montoPagado,
        saldoPendiente: saldoPendiente,
        estadoPago: estadoPago,
      );
    }
  }
}
