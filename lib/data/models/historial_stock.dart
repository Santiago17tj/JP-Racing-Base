import 'package:uuid/uuid.dart';
import '../../core/constants/enums.dart';

const _uuid = Uuid();

/// Modelo de auditoría para movimientos de inventario.
///
/// Refleja la tabla `historial_stock` del modelo de datos.
/// Es append-only: solo se crean registros, nunca se actualizan ni eliminan.
class HistorialStock {
  final String id;
  final String repuestoId;
  final String? ordenId;
  final TipoMovimiento tipoMovimiento;
  final int cantidad;
  final int stockAnterior;
  final int stockPosterior;
  final String? motivo;
  final DateTime createdAt;

  HistorialStock({
    String? id,
    required this.repuestoId,
    this.ordenId,
    required this.tipoMovimiento,
    required this.cantidad,
    required this.stockAnterior,
    required this.stockPosterior,
    this.motivo,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  /// Convierte a Map para insertar en SQLite.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'repuesto_id': repuestoId,
      'orden_id': ordenId,
      'tipo_movimiento': tipoMovimiento.value,
      'cantidad': cantidad,
      'stock_anterior': stockAnterior,
      'stock_posterior': stockPosterior,
      'motivo': motivo,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Crea una instancia desde un Map de SQLite.
  factory HistorialStock.fromMap(Map<String, dynamic> map) {
    return HistorialStock(
      id: map['id'] as String,
      repuestoId: map['repuesto_id'] as String,
      ordenId: map['orden_id'] as String?,
      tipoMovimiento: TipoMovimiento.fromValue(map['tipo_movimiento'] as String),
      cantidad: map['cantidad'] as int,
      stockAnterior: map['stock_anterior'] as int,
      stockPosterior: map['stock_posterior'] as int,
      motivo: map['motivo'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
