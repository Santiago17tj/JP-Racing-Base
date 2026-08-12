import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Modelo para representar transacciones de caja (Ingresos y Egresos).
class RegistroCaja {
  final String id;
  final String? tallerId;
  final String tipo; // 'ingreso' o 'egreso'
  final double monto;
  final String concepto;
  final String? referenciaId; // ID de la orden o factura asociada
  final DateTime fecha;

  RegistroCaja({
    String? id,
    this.tallerId,
    required this.tipo,
    required this.monto,
    required this.concepto,
    this.referenciaId,
    DateTime? fecha,
  })  : id = id ?? _uuid.v4(),
        fecha = fecha ?? DateTime.now();

  RegistroCaja copyWith({
    String? tallerId,
    String? tipo,
    double? monto,
    String? concepto,
    String? referenciaId,
    DateTime? fecha,
  }) {
    return RegistroCaja(
      id: id,
      tallerId: tallerId ?? this.tallerId,
      tipo: tipo ?? this.tipo,
      monto: monto ?? this.monto,
      concepto: concepto ?? this.concepto,
      referenciaId: referenciaId ?? this.referenciaId,
      fecha: fecha ?? this.fecha,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taller_id': tallerId,
      'tipo': tipo,
      'monto': monto,
      'concepto': concepto,
      'referencia_id': referenciaId,
      'fecha': fecha.toIso8601String(),
    };
  }

  factory RegistroCaja.fromMap(Map<String, dynamic> map) {
    return RegistroCaja(
      id: map['id'] as String,
      tallerId: map['taller_id'] as String?,
      tipo: map['tipo'] as String,
      monto: (map['monto'] as num?)?.toDouble() ?? 0.0,
      concepto: map['concepto'] as String,
      referenciaId: map['referencia_id'] as String?,
      fecha: DateTime.parse(map['fecha'] as String),
    );
  }
}
