import 'package:flutter/foundation.dart';
import '../../core/dominio/reglas_orden.dart';
import '../../core/constants/enums.dart';
import '../database/database_helper.dart';
import '../database/fuente_de_datos.dart';
import '../models/orden_mantenimiento.dart';
import '../models/orden_item.dart';
import '../models/cliente.dart';
import '../models/vehiculo.dart';
import '../models/repuesto.dart';
import '../models/registro_caja.dart';
import '../models/abono.dart';

/// Proveedor para manejar el estado de las órdenes de mantenimiento.
class OrdenesProvider extends ChangeNotifier {
  final FuenteDeDatos _db;

  /// Sin argumentos usa la base real, igual que siempre. Las pruebas le pasan
  /// una `FuenteDeDatosFalsa` para no depender de SQLite ni de Supabase.
  OrdenesProvider({FuenteDeDatos? db}) : _db = db ?? DatabaseHelper.instance;

  List<OrdenMantenimiento> _ordenesActivas = [];
  List<OrdenMantenimiento> get ordenesActivas => _ordenesActivas;

  /// Órdenes ya entregadas o canceladas: el historial del taller.
  /// Se carga por páginas para que un taller con años de trabajo no tenga que
  /// descargar todo el archivo cada vez que abre la app.
  static const int tamanoPaginaHistorial = 50;

  List<OrdenMantenimiento> _historial = [];
  List<OrdenMantenimiento> get historial => _historial;

  bool _hayMasHistorial = true;
  bool get hayMasHistorial => _hayMasHistorial;

  bool _cargandoHistorial = false;
  bool get cargandoHistorial => _cargandoHistorial;

  List<Cliente> _clientes = [];
  List<Cliente> get clientes => _clientes;

  List<RegistroCaja> _movimientosCaja = [];
  List<RegistroCaja> get movimientosCaja => _movimientosCaja;

  // Índices en memoria para resolver el cliente y la moto de cada orden sin
  // ir a la base de datos una vez por tarjeta.
  Map<String, Cliente> _clientesPorId = {};
  Map<String, Vehiculo> _vehiculosPorId = {};

  Cliente? clienteDe(String clienteId) => _clientesPorId[clienteId];
  Vehiculo? vehiculoDe(String vehiculoId) => _vehiculosPorId[vehiculoId];

  /// Índices completos, para cálculos que recorren todas las órdenes.
  Map<String, Cliente> get clientesPorId => Map.unmodifiable(_clientesPorId);
  Map<String, Vehiculo> get vehiculosPorId => Map.unmodifiable(_vehiculosPorId);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Carga órdenes activas del taller, clientes y vehículos.
  Future<void> cargarDatos() async {
    _isLoading = true;
    notifyListeners();

    try {
      _ordenesActivas = await _db.getOrdenesActivas();
      _clientes = await _db.getClientes();
      _movimientosCaja = await _db.getRegistrosCaja();
      _historial =
          await _db.getHistorialOrdenes(limite: tamanoPaginaHistorial);
      _hayMasHistorial = _historial.length == tamanoPaginaHistorial;

      final vehiculos = await _db.getVehiculos();
      _clientesPorId = {for (final c in _clientes) c.id: c};
      _vehiculosPorId = {for (final v in vehiculos) v.id: v};
    } catch (e) {
      debugPrint('Error cargando órdenes: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Trae la siguiente página del historial y la agrega a la lista actual.
  Future<void> cargarMasHistorial() async {
    if (_cargandoHistorial || !_hayMasHistorial) return;
    _cargandoHistorial = true;
    notifyListeners();

    try {
      final pagina = await _db.getHistorialOrdenes(
        limite: tamanoPaginaHistorial,
        desplazamiento: _historial.length,
      );
      // Evita duplicados si algo cambió de estado entre una página y otra.
      final conocidas = _historial.map((o) => o.id).toSet();
      _historial.addAll(pagina.where((o) => !conocidas.contains(o.id)));
      _hayMasHistorial = pagina.length == tamanoPaginaHistorial;
    } catch (e) {
      debugPrint('Error cargando más historial: $e');
    }

    _cargandoHistorial = false;
    notifyListeners();
  }

  /// Filtra y obtiene órdenes activas por estado específico para las tabs.
  List<OrdenMantenimiento> getOrdenesPorEstado(EstadoOrden estado) {
    return _ordenesActivas.where((o) => o.estado == estado).toList();
  }

  /// Crea una orden de mantenimiento nueva completa con Cliente y Vehículo rápido.
  Future<void> crearOrdenRapida({
    required String nombreCliente,
    required String apellidoCliente,
    required String telefonoCliente,
    required String numeroDocumentoCliente,
    TipoDocumento tipoDocumento = TipoDocumento.cc,
    String? digitoVerificacion,
    RegimenFiscal? regimenFiscal,
    String? codigoMunicipioDane,
    String? emailCliente,
    String? direccionCliente,
    required String placaPatente,
    required String marca,
    required String modelo,
    required int anio,
    required int kilometrajeIngreso,
    required String descripcionProblema,
    required String mecanicoAsignado,
    required String tipoServicio,
    List<String> fotosEstado = const [],
    bool esCotizacion = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Crear e insertar cliente rápido
      final cliente = Cliente(
        nombre: nombreCliente,
        apellido: apellidoCliente,
        tipoDocumento: tipoDocumento,
        numeroDocumento: numeroDocumentoCliente,
        digitoVerificacion: digitoVerificacion ?? (tipoDocumento == TipoDocumento.nit ? Cliente.calcularDV(numeroDocumentoCliente) : null),
        regimenFiscal: regimenFiscal ?? RegimenFiscal.noResponsable,
        codigoMunicipioDane: codigoMunicipioDane ?? '68001',
        telefono: telefonoCliente,
        email: emailCliente,
        direccion: direccionCliente,
      );
      await _db.insertCliente(cliente);

      // 2. Crear e insertar vehículo
      final vehiculo = Vehiculo(
        clienteId: cliente.id,
        placaPatente: placaPatente.toUpperCase(),
        marca: marca,
        modelo: modelo,
        anio: anio,
        kilometrajeActual: kilometrajeIngreso,
      );
      await _db.insertVehiculo(vehiculo);

      // 3. Crear orden
      final numeroOrden = await _db.generarSiguienteNumeroOrden();
      final orden = OrdenMantenimiento(
        numeroOrden: numeroOrden,
        clienteId: cliente.id,
        vehiculoId: vehiculo.id,
        tipoServicio: tipoServicio,
        kilometrajeIngreso: kilometrajeIngreso,
        descripcionProblema: descripcionProblema,
        mecanicoAsignado: mecanicoAsignado,
        estado: EstadoOrden.ingresada,
        fotosEstado: fotosEstado,
        esCotizacion: esCotizacion,
      );
      await _db.insertOrden(orden);

      // Recargar órdenes
      await cargarDatos();
    } catch (e) {
      debugPrint('Error creando orden: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Crea una orden para un cliente y vehículo que ya existen.
  Future<void> crearOrdenClienteExistente({
    required String clienteId,
    required String vehiculoId,
    required int kilometrajeIngreso,
    required String descripcionProblema,
    required String mecanicoAsignado,
    required String tipoServicio,
    List<String> fotosEstado = const [],
    bool esCotizacion = false,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final numeroOrden = await _db.generarSiguienteNumeroOrden();
      final orden = OrdenMantenimiento(
        numeroOrden: numeroOrden,
        clienteId: clienteId,
        vehiculoId: vehiculoId,
        tipoServicio: tipoServicio,
        kilometrajeIngreso: kilometrajeIngreso,
        descripcionProblema: descripcionProblema,
        mecanicoAsignado: mecanicoAsignado,
        estado: EstadoOrden.ingresada,
        fotosEstado: fotosEstado,
        esCotizacion: esCotizacion,
      );
      await _db.insertOrden(orden);

      // Actualizar kilometraje en el vehículo
      final vehiculo = await _db.getVehiculo(vehiculoId);
      if (vehiculo != null && kilometrajeIngreso > vehiculo.kilometrajeActual) {
        await _db.insertVehiculo(vehiculo.copyWith(kilometrajeActual: kilometrajeIngreso));
      }

      await cargarDatos();
    } catch (e) {
      debugPrint('Error creando orden: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Cambia el estado de una orden.
  Future<void> cambiarEstadoOrden(String ordenId, EstadoOrden nuevoEstado) async {
    try {
      final orden = await _db.getOrden(ordenId);
      if (orden != null) {
        final DateTime? fechaEntrega = nuevoEstado == EstadoOrden.entregada || nuevoEstado == EstadoOrden.listaParaEntrega
            ? DateTime.now()
            : null;
            
        final updated = orden.copyWith(
          estado: nuevoEstado,
          fechaEntrega: fechaEntrega,
        );
        await _db.updateOrden(updated);
        await cargarDatos();
      }
    } catch (e) {
      debugPrint('Error actualizando estado de la orden: $e');
    }
  }

  /// Agrega mano de obra a la orden de mantenimiento.
  Future<void> agregarManoObra(String ordenId, double monto, String concepto) async {
    try {
      await _db.agregarManoObraAOrden(ordenId, monto, concepto);
      await cargarDatos();
    } catch (e) {
      debugPrint('Error agregando mano de obra: $e');
    }
  }

  /// Actualiza los datos de cabecera de una orden ya abierta.
  ///
  /// [esCotizacion] **solo cambia la etiqueta de aquí en adelante**: los
  /// repuestos que ya se añadieron mantienen el stock que descontaron (o que no
  /// descontaron). Convertir una orden trabajada en cotización no le devuelve
  /// nada al inventario, y al revés tampoco se lo quita. Ajustar el stock
  /// retroactivamente sería peor: el mecánico ya tiene las piezas montadas en
  /// la moto. La pantalla avisa de esto antes de guardar.
  Future<void> actualizarOrdenCompleta(
    String ordenId, {
    String? clienteId,
    String? vehiculoId,
    String? mecanico,
    String? tipoServicio,
    int? kilometraje,
    String? descripcion,
    DateTime? fechaIngreso,
    bool? esCotizacion,
  }) async {
    try {
      final orden = await _db.getOrden(ordenId);
      if (orden != null) {
        final updated = orden.copyWith(
          clienteId: clienteId ?? orden.clienteId,
          vehiculoId: vehiculoId ?? orden.vehiculoId,
          mecanicoAsignado: mecanico ?? orden.mecanicoAsignado,
          tipoServicio: tipoServicio ?? orden.tipoServicio,
          kilometrajeIngreso: kilometraje ?? orden.kilometrajeIngreso,
          descripcionProblema: descripcion ?? orden.descripcionProblema,
          fechaIngreso: fechaIngreso ?? orden.fechaIngreso,
          esCotizacion: esCotizacion ?? orden.esCotizacion,
        );
        await _db.updateOrden(updated);
        await cargarDatos();
      }
    } catch (e) {
      debugPrint('Error al actualizar orden completa: $e');
    }
  }

  /// Agrega un repuesto consumido a la orden (resta stock de inventario automáticamente).
  Future<bool> agregarRepuestoAOrden({
    required String ordenId,
    required Repuesto repuesto,
    required int cantidad,
  }) async {
    try {
      final exito = await _db.agregarItemAOrden(
        ordenId: ordenId,
        repuestoId: repuesto.id,
        cantidad: cantidad,
        precioUnitario: repuesto.precioVenta,
        descripcion: repuesto.nombre,
      );
      if (exito) {
        await cargarDatos();
      }
      return exito;
    } catch (e) {
      debugPrint('Error agregando repuesto a orden: $e');
      return false;
    }
  }

  /// Actualiza diagnóstico y notas internas del mecánico.
  Future<void> actualizarNotasMecanico({
    required String ordenId,
    required String diagnostico,
    required String notasMecanico,
  }) async {
    try {
      final orden = await _db.getOrden(ordenId);
      if (orden != null) {
        final updated = orden.copyWith(
          diagnostico: diagnostico,
          notasMecanico: notasMecanico,
        );
        await _db.updateOrden(updated);
        await cargarDatos();
      }
    } catch (e) {
      debugPrint('Error actualizando notas del mecánico: $e');
    }
  }

  /// Obtiene los ítems consumidos en la orden.
  Future<List<OrdenItem>> obtenerItemsOrden(String ordenId) async {
    return await _db.getItemsDeOrden(ordenId);
  }

  /// Elimina un ítem de la orden (repuesto o mano de obra).
  /// Restaura el stock si era un repuesto de inventario, y recalcula costoManoObra si era labor.
  Future<bool> eliminarItemDeOrden({
    required String itemId,
    required String ordenId,
  }) async {
    try {
      final exito = await _db.eliminarItemDeOrden(itemId: itemId, ordenId: ordenId);
      if (exito) {
        await cargarDatos();
      }
      return exito;
    } catch (e) {
      debugPrint('Error eliminando item de orden: $e');
      return false;
    }
  }

  /// Agrega un repuesto externo/fuera de inventario con nombre y precio personalizado.
  Future<bool> agregarRepuestoExterno({
    required String ordenId,
    required String nombre,
    required double precio,
    required int cantidad,
  }) async {
    try {
      final exito = await _db.agregarItemLibreAOrden(
        ordenId: ordenId,
        nombre: nombre,
        precio: precio,
        cantidad: cantidad,
      );
      if (exito) {
        await cargarDatos();
      }
      return exito;
    } catch (e) {
      debugPrint('Error agregando repuesto externo: $e');
      return false;
    }
  }

  /// Obtiene la lista de vehículos para un cliente específico.
  Future<List<Vehiculo>> obtenerVehiculosDeCliente(String clienteId) async {
    return await _db.getVehiculosPorCliente(clienteId);
  }

  /// Obtiene el cliente asociado a una orden.
  Future<Cliente?> obtenerClienteDeOrden(String clienteId) async {
    return await _db.getCliente(clienteId);
  }

  /// Obtiene el vehículo asociado a una orden.
  Future<Vehiculo?> obtenerVehiculoDeOrden(String vehiculoId) async {
    return await _db.getVehiculo(vehiculoId);
  }

  /// Edita un registro de caja existente.
  Future<void> editarRegistroCaja(String id, double monto, String concepto, String tipo) async {
    try {
      await _db.editarRegistroCaja(id, monto, concepto, tipo);
      await cargarDatos();
    } catch (e) {
      debugPrint('Error editando registro de caja: $e');
    }
  }

  /// Registra un movimiento manual en la caja.
  Future<void> registrarMovimientoManual(double monto, String concepto, String tipo) async {
    try {
      final reg = RegistroCaja(
        monto: monto,
        concepto: concepto,
        tipo: tipo,
        fecha: DateTime.now(),
      );
      await _db.insertRegistroCaja(reg);
      await cargarDatos();
    } catch (e) {
      debugPrint('Error registrarMovimientoManual: $e');
    }
  }

  /// Procesa una venta rápida de mostrador.
  Future<void> procesarVentaRapida({
    required Map<Repuesto, int> items,
    required double totalVenta,
    required double totalCosto,
  }) async {
    try {
      // 1. Reducir inventario
      for (final entry in items.entries) {
        final repuesto = entry.key;
        final cantidad = entry.value;
        final updatedRepuesto = repuesto.copyWith(
          stockActual: repuesto.stockActual - cantidad,
        );
        await _db.updateRepuesto(updatedRepuesto);
      }

      // 2. Registrar el ingreso en la caja
      final concepto = 'Venta rápida de mostrador (${items.values.fold(0, (a, b) => a + b)} items)';
      await registrarMovimientoManual(totalVenta, concepto, 'ingreso');
      
    } catch (e) {
      debugPrint('Error procesando venta rápida: $e');
      rethrow;
    }
  }

  /// Obtiene los abonos registrados para una orden.
  Future<List<Abono>> obtenerAbonosDeOrden(String ordenId) async {
    return await _db.obtenerAbonosDeOrden(ordenId);
  }

  /// Registra un abono/anticipo para una orden de mantenimiento:
  /// a) Crea la fila en orden_abonos
  /// b) Recalcula monto_pagado, saldo_pendiente y estado_pago de la orden
  /// c) Registra el ingreso automáticamente en la caja/contabilidad
  /// d) Notifica a los escuchas y recarga los datos
  /// Registra un abono y recalcula lo que queda por cobrar.
  ///
  /// [porcentajeImpuesto] es obligatorio a propósito: el saldo se calculaba
  /// sobre `totalEstimado`, que es la suma **sin IVA**, así que quedaba por
  /// debajo del real. En una orden con 250.000 de mano de obra al 19%, el
  /// cliente veía 47.500 pesos menos de deuda. La pantalla de la orden mostraba
  /// el saldo correcto y la factura el equivocado.
  Future<void> registrarAbono({
    required String ordenId,
    required double monto,
    required String metodoPago,
    required double porcentajeImpuesto,
    String? notas,
  }) async {
    try {
      final abono = Abono(
        ordenId: ordenId,
        monto: monto,
        metodoPago: metodoPago,
        fecha: DateTime.now(),
        notas: notas,
      );
      await _db.insertarAbono(abono);

      // Obtener orden actual para recalcular montos
      final ordenes = await _db.getOrdenesActivas();
      final idx = ordenes.indexWhere((o) => o.id == ordenId);
      if (idx != -1) {
        final orden = ordenes[idx];
        final nuevoMontoPagado = orden.montoPagado + monto;
        // Por ReglasOrden y sobre el total CON impuesto, que es lo que el
        // cliente paga de verdad.
        final saldoFinal = ReglasOrden.saldoPendiente(
          total: orden.totalConImpuesto(porcentajeImpuesto),
          montoPagado: nuevoMontoPagado,
        );
        final nuevoEstadoPago = saldoFinal <= 0 ? 'pagado' : (nuevoMontoPagado > 0 ? 'parcial' : 'pendiente');

        await _db.actualizarPagoOrden(
          ordenId: ordenId,
          montoPagado: nuevoMontoPagado,
          saldoPendiente: saldoFinal,
          estadoPago: nuevoEstadoPago,
        );

        // Registrar ingreso en caja contable
        final concepto = 'Abono Orden #${orden.numeroOrden} (${metodoPago.toUpperCase()})';
        await registrarMovimientoManual(monto, concepto, 'ingreso');
      }

      await cargarDatos();
    } catch (e) {
      debugPrint('Error registrando abono: $e');
      rethrow;
    }
  }

  /// Limpia los datos almacenados en la sesión actual
  void limpiarDatos() {
    _ordenesActivas.clear();
    _clientes.clear();
    _movimientosCaja.clear();
    _historial.clear();
    _hayMasHistorial = true;
    _clientesPorId.clear();
    _vehiculosPorId.clear();
    notifyListeners();
  }
}

