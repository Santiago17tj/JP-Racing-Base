import 'package:uuid/uuid.dart';
import '../../core/constants/enums.dart';

const _uuid = Uuid();

/// Registro principal de orden de mantenimiento.
class OrdenMantenimiento {
  final String id;
  final String numeroOrden;
  final String clienteId;
  final String vehiculoId;
  final EstadoOrden estado;
  final TipoServicio tipoServicio;
  final int kilometrajeIngreso;
  final String? descripcionProblema;
  final String? diagnostico;
  final String? notasMecanico;
  final String? mecanicoAsignado;
  final double costoManoObra;
  final double subtotalRepuestos;
  final double totalEstimado;
  final DateTime fechaIngreso;
  final DateTime? fechaPromesa;
  final DateTime? fechaEntrega;
  final DateTime createdAt;
  final DateTime updatedAt;

  OrdenMantenimiento({
    String? id,
    required this.numeroOrden,
    required this.clienteId,
    required this.vehiculoId,
    this.estado = EstadoOrden.ingresada,
    required this.tipoServicio,
    required this.kilometrajeIngreso,
    this.descripcionProblema,
    this.diagnostico,
    this.notasMecanico,
    this.mecanicoAsignado,
    this.costoManoObra = 0.0,
    this.subtotalRepuestos = 0.0,
    DateTime? fechaIngreso,
    this.fechaPromesa,
    this.fechaEntrega,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        totalEstimado = costoManoObra + subtotalRepuestos,
        fechaIngreso = fechaIngreso ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Calcula los días que la moto lleva en el taller.
  int get diasEnTaller {
    final fin = fechaEntrega ?? DateTime.now();
    return fin.difference(fechaIngreso).inDays;
  }

  String? get notesMecanico => notasMecanico;

  OrdenMantenimiento copyWith({
    EstadoOrden? estado,
    String? diagnostico,
    String? notasMecanico,
    String? mecanicoAsignado,
    double? costoManoObra,
    double? subtotalRepuestos,
    DateTime? fechaEntrega,
  }) {
    return OrdenMantenimiento(
      id: id,
      numeroOrden: numeroOrden,
      clienteId: clienteId,
      vehiculoId: vehiculoId,
      estado: estado ?? this.estado,
      tipoServicio: tipoServicio,
      kilometrajeIngreso: kilometrajeIngreso,
      descripcionProblema: descripcionProblema,
      diagnostico: diagnostico ?? this.diagnostico,
      notasMecanico: notasMecanico ?? this.notasMecanico,
      mecanicoAsignado: mecanicoAsignado ?? this.mecanicoAsignado,
      costoManoObra: costoManoObra ?? this.costoManoObra,
      subtotalRepuestos: subtotalRepuestos ?? this.subtotalRepuestos,
      fechaIngreso: fechaIngreso,
      fechaPromesa: fechaPromesa,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero_orden': numeroOrden,
      'cliente_id': clienteId,
      'vehiculo_id': vehiculoId,
      'estado': estado.value,
      'tipo_servicio': tipoServicio.value,
      'kilometraje_ingreso': kilometrajeIngreso,
      'descripcion_problema': descripcionProblema,
      'diagnostico': diagnostico,
      'notas_mecanico': notasMecanico,
      'mecanico_assigned': mecanicoAsignado, // Map to mecanico_asignado in SQL mapping helper
      'costo_mano_obra': costoManoObra,
      'subtotal_repuestos': subtotalRepuestos,
      'total_estimado': totalEstimado,
      'fecha_ingreso': fechaIngreso.toIso8601String(),
      'fecha_promesa': fechaPromesa?.toIso8601String(),
      'fecha_entrega': fechaEntrega?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory OrdenMantenimiento.fromMap(Map<String, dynamic> map) {
    return OrdenMantenimiento(
      id: map['id'] as String,
      numeroOrden: map['numero_orden'] as String,
      clienteId: map['cliente_id'] as String,
      vehiculoId: map['vehiculo_id'] as String,
      estado: EstadoOrden.fromValue(map['estado'] as String),
      tipoServicio: TipoServicio.fromValue(map['tipo_servicio'] as String),
      kilometrajeIngreso: map['kilometraje_ingreso'] as int,
      descripcionProblema: map['descripcion_problema'] as String?,
      diagnostico: map['diagnostico'] as String?,
      notasMecanico: map['notas_mecanico'] as String?,
      mecanicoAsignado: map['mecanico_asignado'] as String? ?? map['mecanico_assigned'] as String?,
      costoManoObra: (map['costo_mano_obra'] as num).toDouble(),
      subtotalRepuestos: (map['subtotal_repuestos'] as num).toDouble(),
      fechaIngreso: DateTime.parse(map['fecha_ingreso'] as String),
      fechaPromesa: map['fecha_promesa'] != null ? DateTime.parse(map['fecha_promesa'] as String) : null,
      fechaEntrega: map['fecha_entrega'] != null ? DateTime.parse(map['fecha_entrega'] as String) : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
