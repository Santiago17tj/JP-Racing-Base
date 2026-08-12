import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Modelo de datos para un Abono / Pago parcial asignado a una orden de mantenimiento.
class Abono {
  final String id;
  final String ordenId;
  final double monto;
  final String metodoPago; // 'efectivo', 'transferencia', 'tarjeta', 'nequi', 'daviplata'
  final DateTime fecha;
  final String? notas;
  final DateTime createdAt;

  Abono({
    String? id,
    required this.ordenId,
    required this.monto,
    required this.metodoPago,
    DateTime? fecha,
    this.notas,
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        fecha = fecha ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orden_id': ordenId,
      'monto': monto,
      'metodo_pago': metodoPago,
      'fecha': fecha.toIso8601String(),
      'notas': notas,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Abono.fromMap(Map<String, dynamic> map) {
    return Abono(
      id: map['id'] as String,
      ordenId: map['orden_id'] as String,
      monto: (map['monto'] as num).toDouble(),
      metodoPago: map['metodo_pago'] as String? ?? 'efectivo',
      fecha: DateTime.tryParse(map['fecha']?.toString() ?? '') ?? DateTime.now(),
      notas: map['notas'] as String?,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  factory Abono.fromJson(Map<String, dynamic> json) => Abono.fromMap(json);
}
