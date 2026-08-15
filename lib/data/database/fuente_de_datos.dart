import '../models/abono.dart';
import '../models/cliente.dart';
import '../models/historial_stock.dart';
import '../models/orden_item.dart';
import '../models/orden_mantenimiento.dart';
import '../models/perfil_taller.dart';
import '../models/registro_caja.dart';
import '../models/repuesto.dart';
import '../models/vehiculo.dart';

/// Lo que los providers necesitan de la base de datos, y nada más.
///
/// `DatabaseHelper` la implementa sin cambiar una línea de comportamiento: esto
/// es solo una declaración. Sirve para que las pruebas de pantalla puedan
/// sustituir la base por una falsa en memoria (`FuenteDeDatosFalsa`, en
/// `test/`) sin arrastrar SQLite ni Supabase.
///
/// Son los métodos que hoy usan `OrdenesProvider`, `InventarioProvider` y
/// `TallerProvider`. Se sacan con:
///
/// ```bash
/// grep -ohE "_db\.[a-zA-Z]+|DatabaseHelper\.instance\.[a-zA-Z]+" \
///   lib/data/providers/*.dart | sed 's/.*\.//' | sort -u
/// ```
///
/// Si un provider empieza a usar un método nuevo de `DatabaseHelper`, no
/// compilará hasta añadirlo aquí. Eso es a propósito.
abstract class FuenteDeDatos {
  // ── Sincronización ────────────────────────────
  Future<void> sincronizarDesdeNube(String tallerId);
  Future<int> limpiarDatosDeOtrosTalleres(String tallerActivo);

  // ── Perfil del taller ─────────────────────────
  Future<PerfilTaller> insertPerfilTaller(PerfilTaller taller);
  Future<PerfilTaller?> getPerfilTallerLocal(String usuarioId);
  Future<void> savePerfilTallerLocal(PerfilTaller taller);

  // ── Clientes ──────────────────────────────────
  Future<void> insertCliente(Cliente cliente);
  Future<List<Cliente>> getClientes();
  Future<Cliente?> getCliente(String id);

  // ── Vehículos ─────────────────────────────────
  Future<void> insertVehiculo(Vehiculo vehiculo);
  Future<List<Vehiculo>> getVehiculos();
  Future<List<Vehiculo>> getVehiculosPorCliente(String clienteId);
  Future<Vehiculo?> getVehiculo(String id);

  // ── Inventario ────────────────────────────────
  Future<void> insertRepuesto(Repuesto repuesto);
  Future<List<Repuesto>> getRepuestos({
    String? busqueda,
    String? categoria,
    bool soloStockBajo = false,
  });
  Future<Repuesto?> getRepuestoPorCodigo(String codigoInterno);
  Future<void> updateRepuesto(Repuesto repuesto);
  Future<void> deleteRepuesto(String id);
  Future<int> contarStockBajo();
  Future<Repuesto?> ajustarStock({
    required String repuestoId,
    required int delta,
    String? motivo,
    String? ordenId,
  });
  Future<List<HistorialStock>> getHistorial(String repuestoId);

  // ── Órdenes ───────────────────────────────────
  Future<void> insertOrden(OrdenMantenimiento orden);
  Future<List<OrdenMantenimiento>> getOrdenesActivas();
  Future<List<OrdenMantenimiento>> getHistorialOrdenes({
    int limite = 50,
    int desplazamiento = 0,
  });
  Future<OrdenMantenimiento?> getOrden(String id);
  Future<void> updateOrden(OrdenMantenimiento orden);
  Future<String> generarSiguienteNumeroOrden();

  // ── Ítems de orden ────────────────────────────
  Future<List<OrdenItem>> getItemsDeOrden(String ordenId);
  Future<bool> agregarItemAOrden({
    required String ordenId,
    required String repuestoId,
    required int cantidad,
    required double precioUnitario,
    required String descripcion,
  });
  Future<bool> agregarItemLibreAOrden({
    required String ordenId,
    required String nombre,
    required double precio,
    required int cantidad,
  });
  Future<bool> eliminarItemDeOrden({
    required String itemId,
    required String ordenId,
  });
  Future<void> agregarManoObraAOrden(
      String ordenId, double monto, String concepto);

  // ── Caja y abonos ─────────────────────────────
  Future<void> insertRegistroCaja(RegistroCaja registro);
  Future<List<RegistroCaja>> getRegistrosCaja();
  Future<void> editarRegistroCaja(
      String id, double monto, String concepto, String tipo);
  Future<void> insertarAbono(Abono abono);
  Future<List<Abono>> obtenerAbonosDeOrden(String ordenId);
  Future<void> actualizarPagoOrden({
    required String ordenId,
    required double montoPagado,
    required double saldoPendiente,
    required String estadoPago,
  });
}
