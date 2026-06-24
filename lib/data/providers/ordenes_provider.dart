import 'package:flutter/foundation.dart';
import '../../core/constants/enums.dart';
import '../database/database_helper.dart';
import '../models/orden_mantenimiento.dart';
import '../models/orden_item.dart';
import '../models/cliente.dart';
import '../models/vehiculo.dart';
import '../models/repuesto.dart';

/// Proveedor para manejar el estado de las órdenes de mantenimiento.
class OrdenesProvider extends ChangeNotifier {
  final DatabaseHelper _db = DatabaseHelper.instance;

  List<OrdenMantenimiento> _ordenesActivas = [];
  List<OrdenMantenimiento> get ordenesActivas => _ordenesActivas;

  List<Cliente> _clientes = [];
  List<Cliente> get clientes => _clientes;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Carga órdenes activas del taller, clientes y vehículos.
  Future<void> cargarDatos() async {
    _isLoading = true;
    notifyListeners();

    try {
      _ordenesActivas = await _db.getOrdenesActivas();
      _clientes = await _db.getClientes();
    } catch (e) {
      debugPrint('Error cargando órdenes: $e');
    }

    _isLoading = false;
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
    required String placaPatente,
    required String marca,
    required String modelo,
    required int anio,
    required int kilometrajeIngreso,
    required String descripcionProblema,
    required String mecanicoAsignado,
    required TipoServicio tipoServicio,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // 1. Crear e insertar cliente rápido
      final cliente = Cliente(
        nombre: nombreCliente,
        apellido: apellidoCliente,
        tipoDocumento: TipoDocumento.dni,
        numeroDocumento: numeroDocumentoCliente,
        telefono: telefonoCliente,
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
    required TipoServicio tipoServicio,
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
}
