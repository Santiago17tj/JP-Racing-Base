import 'dart:convert';
import 'package:uuid/uuid.dart';
import '../../core/constants/enums.dart';
import '../../core/dominio/reglas_orden.dart';

const _uuid = Uuid();

/// Registro principal de orden de mantenimiento.
class OrdenMantenimiento {
  final String id;
  final String? tallerId;
  final String numeroOrden;
  final String clienteId;
  final String vehiculoId;
  final EstadoOrden estado;
  final String tipoServicio;
  final int kilometrajeIngreso;
  final String? descripcionProblema;
  final String? diagnostico;
  final String? notasMecanico;
  final String? mecanicoAsignado;
  final double costoManoObra;
  final double subtotalRepuestos;
  final double totalEstimado;
  final double montoPagado;
  final double saldoPendiente;
  final String estadoPago; // 'pendiente', 'parcial', 'pagado'
  final DateTime fechaIngreso;
  final DateTime? fechaPromesa;
  final DateTime? fechaEntrega;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> fotosEstado;
  final bool esCotizacion;

  OrdenMantenimiento({
    String? id,
    this.tallerId,
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
    double montoPagado = 0.0,
    double? saldoPendiente,
    String? estadoPago,
    DateTime? fechaIngreso,
    this.fechaPromesa,
    this.fechaEntrega,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? fotosEstado,
    this.esCotizacion = false,
  })  : id = id ?? _uuid.v4(),
        totalEstimado = costoManoObra + subtotalRepuestos,
        montoPagado = montoPagado < 0 ? 0.0 : montoPagado,
        saldoPendiente = saldoPendiente ??
            (((costoManoObra + subtotalRepuestos) - montoPagado) < 0
                ? 0.0
                : ((costoManoObra + subtotalRepuestos) - montoPagado)),
        estadoPago = estadoPago ??
            (((costoManoObra + subtotalRepuestos) - montoPagado) <= 0
                ? 'pagado'
                : (montoPagado > 0 ? 'parcial' : 'pendiente')),
        fechaIngreso = fechaIngreso ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        fotosEstado = fotosEstado ?? [];

  int get diasEnTaller {
    final fin = fechaEntrega ?? DateTime.now();
    return fin.difference(fechaIngreso).inDays;
  }

  String? get notesMecanico => notasMecanico;

  /// IVA de la orden. Solo grava la mano de obra: los repuestos se venden
  /// con el impuesto ya incluido en el precio de venta.
  double impuestoManoObra(double porcentaje) =>
      ReglasOrden.impuesto(costoManoObra, porcentaje);

  /// Total a cobrar incluyendo el IVA de la mano de obra.
  double totalConImpuesto(double porcentaje) => ReglasOrden.total(
        subtotalRepuestos: subtotalRepuestos,
        costoManoObra: costoManoObra,
        porcentajeImpuesto: porcentaje,
      );

  /// Saldo por cobrar una vez descontados los abonos, con IVA incluido.
  double saldoPendienteConImpuesto(double porcentaje) =>
      ReglasOrden.saldoPendiente(
        total: totalConImpuesto(porcentaje),
        montoPagado: montoPagado,
      );

  OrdenMantenimiento copyWith({
    String? tallerId,
    String? clienteId,
    String? vehiculoId,
    EstadoOrden? estado,
    String? tipoServicio,
    int? kilometrajeIngreso,
    String? descripcionProblema,
    String? diagnostico,
    String? notasMecanico,
    String? mecanicoAsignado,
    double? costoManoObra,
    double? subtotalRepuestos,
    double? montoPagado,
    double? saldoPendiente,
    String? estadoPago,
    DateTime? fechaIngreso,
    DateTime? fechaEntrega,
    List<String>? fotosEstado,
    bool? esCotizacion,
  }) {
    return OrdenMantenimiento(
      id: id,
      tallerId: tallerId ?? this.tallerId,
      numeroOrden: numeroOrden,
      clienteId: clienteId ?? this.clienteId,
      vehiculoId: vehiculoId ?? this.vehiculoId,
      estado: estado ?? this.estado,
      tipoServicio: tipoServicio ?? this.tipoServicio,
      kilometrajeIngreso: kilometrajeIngreso ?? this.kilometrajeIngreso,
      descripcionProblema: descripcionProblema ?? this.descripcionProblema,
      diagnostico: diagnostico ?? this.diagnostico,
      notasMecanico: notasMecanico ?? this.notasMecanico,
      mecanicoAsignado: mecanicoAsignado ?? this.mecanicoAsignado,
      costoManoObra: costoManoObra ?? this.costoManoObra,
      subtotalRepuestos: subtotalRepuestos ?? this.subtotalRepuestos,
      montoPagado: montoPagado ?? this.montoPagado,
      saldoPendiente: saldoPendiente ?? this.saldoPendiente,
      estadoPago: estadoPago ?? this.estadoPago,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      fechaPromesa: fechaPromesa,
      fechaEntrega: fechaEntrega ?? this.fechaEntrega,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      fotosEstado: fotosEstado ?? this.fotosEstado,
      esCotizacion: esCotizacion ?? this.esCotizacion,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taller_id': tallerId,
      'numero_orden': numeroOrden,
      'cliente_id': clienteId,
      'vehiculo_id': vehiculoId,
      'estado': estado.value,
      'tipo_servicio': tipoServicio,
      'kilometraje_ingreso': kilometrajeIngreso,
      'descripcion_problema': descripcionProblema,
      'diagnostico': diagnostico,
      'notas_mecanico': notasMecanico,
      'mecanico_assigned': mecanicoAsignado,
      'costo_mano_obra': costoManoObra,
      'subtotal_repuestos': subtotalRepuestos,
      'total_estimado': totalEstimado,
      'monto_pagado': montoPagado,
      'saldo_pendiente': saldoPendiente,
      'estado_pago': estadoPago,
      'fecha_ingreso': fechaIngreso.toIso8601String(),
      'fecha_promesa': fechaPromesa?.toIso8601String(),
      'fecha_entrega': fechaEntrega?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'fotos_estado': jsonEncode(fotosEstado),
      'es_cotizacion': esCotizacion ? 1 : 0,
    };
  }

  factory OrdenMantenimiento.fromMap(Map<String, dynamic> map) {
    List<String> parseFotos(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.isNotEmpty) {
        try {
          final decoded = jsonDecode(raw);
          if (decoded is List) return decoded.map((e) => e.toString()).toList();
        } catch (_) {}
      }
      return [];
    }

    final cManoObra = (map['costo_mano_obra'] as num?)?.toDouble() ?? 0.0;
    final sRepuestos = (map['subtotal_repuestos'] as num?)?.toDouble() ?? 0.0;
    final total = cManoObra + sRepuestos;
    final mPagado = (map['monto_pagado'] as num?)?.toDouble() ?? 0.0;
    final sPendiente = (map['saldo_pendiente'] as num?)?.toDouble() ??
        (total - mPagado < 0 ? 0.0 : total - mPagado);
    final ePago = map['estado_pago'] as String? ??
        (sPendiente <= 0 ? 'pagado' : (mPagado > 0 ? 'parcial' : 'pendiente'));

    return OrdenMantenimiento(
      id: map['id'] as String,
      tallerId: map['taller_id'] as String?,
      numeroOrden: map['numero_orden'] as String,
      clienteId: map['cliente_id'] as String,
      vehiculoId: map['vehiculo_id'] as String,
      estado: EstadoOrden.fromValue(map['estado'] as String),
      tipoServicio: TiposServicio.fromValue(map['tipo_servicio'] as String),
      kilometrajeIngreso: (map['kilometraje_ingreso'] as num?)?.toInt() ?? 0,
      descripcionProblema: map['descripcion_problema'] as String?,
      diagnostico: map['diagnostico'] as String?,
      notasMecanico: map['notas_mecanico'] as String?,
      mecanicoAsignado: map['mecanico_asignado'] as String? ??
          map['mecanico_assigned'] as String?,
      costoManoObra: cManoObra,
      subtotalRepuestos: sRepuestos,
      montoPagado: mPagado,
      saldoPendiente: sPendiente,
      estadoPago: ePago,
      fechaIngreso: DateTime.parse(map['fecha_ingreso'] as String),
      fechaPromesa: map['fecha_promesa'] != null
          ? DateTime.parse(map['fecha_promesa'] as String)
          : null,
      fechaEntrega: map['fecha_entrega'] != null
          ? DateTime.parse(map['fecha_entrega'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      fotosEstado: parseFotos(map['fotos_estado']),
      esCotizacion: map['es_cotizacion'] == true || map['es_cotizacion'] == 1,
    );
  }
}
