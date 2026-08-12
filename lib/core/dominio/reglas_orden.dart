import '../../data/models/orden_item.dart';

/// Reglas de negocio de una orden de trabajo, en un solo lugar.
///
/// Antes cada ruta de datos (Supabase, memoria web y SQLite) y cada pantalla
/// repetían estos cálculos por su cuenta, y bastaba con que una copia se
/// quedara atrás para que los totales no cuadraran. Todo el que necesite saber
/// qué es mano de obra o cuánto suman los repuestos debe pasar por aquí.
class ReglasOrden {
  const ReglasOrden._();

  /// Repuesto ficticio con el que se registran los conceptos de mano de obra.
  /// Su valor ya está acumulado en `orden.costoManoObra`.
  ///
  /// Es un UUID y no un texto porque en Supabase `orden_items.repuesto_id` es
  /// de tipo UUID con llave foránea: con el identificador anterior
  /// ('item-mano-obra') cada inserción en la nube fallaba y los ítems se
  /// quedaban solo en el teléfono.
  static const String idManoObra = '00000000-0000-4000-8000-000000000001';

  /// Repuesto ficticio para piezas compradas fuera del inventario.
  static const String idRepuestoExterno =
      '00000000-0000-4000-8000-000000000002';

  /// Identificadores usados antes del cambio a UUID. Se siguen reconociendo
  /// para que los ítems ya guardados en los teléfonos no se descuadren.
  static const String idManoObraAnterior = 'item-mano-obra';
  static const String idRepuestoExternoAnterior = 'item-externo-generico';

  /// Los dos repuestos ficticios, con los datos con los que deben existir en
  /// el inventario (la nube exige que la llave foránea apunte a algo real).
  static const Map<String, ({String nombre, String codigo})> especiales = {
    idManoObra: (nombre: 'Mano de Obra (Generada)', codigo: 'MO-001'),
    idRepuestoExterno: (nombre: 'Repuesto Externo General', codigo: 'EXT-001'),
  };

  /// ¿Este id corresponde a un repuesto ficticio del sistema?
  static bool esEspecial(Object? repuestoId) =>
      repuestoId == idManoObra ||
      repuestoId == idRepuestoExterno ||
      repuestoId == idManoObraAnterior ||
      repuestoId == idRepuestoExternoAnterior;

  /// ¿Este ítem es un concepto de mano de obra?
  static bool esManoObra(OrdenItem item) => esManoObraCrudo(item.repuestoId);

  /// Igual que [esManoObra] pero sobre una fila cruda de la base de datos.
  static bool esManoObraCrudo(Object? repuestoId) =>
      repuestoId == idManoObra || repuestoId == idManoObraAnterior;

  /// Suma de los repuestos de una orden. Excluye la mano de obra, que se
  /// acumula aparte en `costo_mano_obra`; sumarla aquí la cobraría dos veces.
  static double subtotalRepuestos(Iterable<OrdenItem> items) => items
      .where((item) => !esManoObra(item))
      .fold<double>(0.0, (suma, item) => suma + item.subtotal);

  /// Versión para filas crudas de `orden_items` (mapas de la base de datos).
  static double subtotalRepuestosCrudo(Iterable<Map<String, Object?>> filas) {
    double total = 0.0;
    for (final fila in filas) {
      if (esManoObraCrudo(fila['repuesto_id'] ?? fila['repuestoId'] ?? '')) {
        continue;
      }
      final cantidad = (fila['cantidad'] as num?)?.toDouble() ?? 0.0;
      final precio = (fila['precio_unitario'] as num?)?.toDouble() ?? 0.0;
      final descuento = (fila['descuento'] as num?)?.toDouble() ?? 0.0;
      total += cantidad * precio * (1.0 - (descuento / 100.0));
    }
    return total;
  }

  /// Mano de obra desglosada como ítems (solo existe para el detalle de la
  /// factura; el acumulado real vive en `orden.costoManoObra`).
  static double manoObraDetallada(Iterable<OrdenItem> items) => items
      .where(esManoObra)
      .fold<double>(0.0, (suma, item) => suma + item.subtotal);

  /// El IVA grava únicamente la mano de obra: los repuestos se compran con el
  /// impuesto ya incluido en el precio de venta.
  static double impuesto(double costoManoObra, double porcentaje) =>
      porcentaje <= 0 ? 0.0 : costoManoObra * (porcentaje / 100);

  /// Total a cobrar: repuestos + mano de obra + IVA de la mano de obra.
  static double total({
    required double subtotalRepuestos,
    required double costoManoObra,
    required double porcentajeImpuesto,
  }) =>
      subtotalRepuestos +
      costoManoObra +
      impuesto(costoManoObra, porcentajeImpuesto);

  /// Saldo por cobrar una vez descontados los abonos. Nunca negativo.
  static double saldoPendiente({
    required double total,
    required double montoPagado,
  }) {
    final saldo = total - montoPagado;
    return saldo < 0 ? 0.0 : saldo;
  }
}
