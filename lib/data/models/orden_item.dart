import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Línea de detalle de repuesto utilizado en una orden de mantenimiento.
class OrdenItem {
  final String id;
  final String ordenId;
  final String repuestoId;
  final String descripcion;
  final int cantidad;
  final double precioUnitario;
  final double descuento;
  final double subtotal;
  final DateTime createdAt;

  OrdenItem({
    String? id,
    required this.ordenId,
    required this.repuestoId,
    required this.descripcion,
    required this.cantidad,
    required this.precioUnitario,
    this.descuento = 0.0,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        subtotal = cantidad * precioUnitario * (1.0 - (descuento / 100.0)),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orden_id': ordenId,
      'repuesto_id': repuestoId,
      'descripcion': descripcion,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'descuento': descuento,
      'subtotal': subtotal,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory OrdenItem.fromMap(Map<String, dynamic> map) {
    return OrdenItem(
      id: map['id'] as String,
      ordenId: map['orden_id'] as String,
      repuestoId: map['repuesto_id'] as String,
      descripcion: map['descripcion'] as String,
      cantidad: map['cantidad'] as int,
      precioUnitario: (map['precio_unitario'] as num).toDouble(),
      descuento: (map['descuento'] as num).toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
