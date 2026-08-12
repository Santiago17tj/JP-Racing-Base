import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Modelo de datos para el Perfil del Taller (Tenant en la arquitectura SaaS).
class PerfilTaller {
  final String id;
  final String usuarioAdministradorId;
  final String nombreTaller;
  final String? logoUrl;
  final String? telefono;
  final String? direccion;
  final String? ciudad;
  final String moneda;
  final double porcentajeImpuestoDefecto;
  final String? terminosCondicionesFactura;
  final DateTime createdAt;
  final DateTime updatedAt;

  PerfilTaller({
    String? id,
    required this.usuarioAdministradorId,
    required this.nombreTaller,
    this.logoUrl,
    this.telefono,
    this.direccion,
    this.ciudad,
    this.moneda = 'COP',
    this.porcentajeImpuestoDefecto = 0.0,
    this.terminosCondicionesFactura,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  PerfilTaller copyWith({
    String? nombreTaller,
    String? logoUrl,
    String? telefono,
    String? direccion,
    String? ciudad,
    String? moneda,
    double? porcentajeImpuestoDefecto,
    String? terminosCondicionesFactura,
  }) {
    return PerfilTaller(
      id: id,
      usuarioAdministradorId: usuarioAdministradorId,
      nombreTaller: nombreTaller ?? this.nombreTaller,
      logoUrl: logoUrl ?? this.logoUrl,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      ciudad: ciudad ?? this.ciudad,
      moneda: moneda ?? this.moneda,
      porcentajeImpuestoDefecto: porcentajeImpuestoDefecto ?? this.porcentajeImpuestoDefecto,
      terminosCondicionesFactura: terminosCondicionesFactura ?? this.terminosCondicionesFactura,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_administrador_id': usuarioAdministradorId,
      'nombre_taller': nombreTaller,
      'logo_url': logoUrl,
      'telefono': telefono,
      'direccion': direccion,
      'ciudad': ciudad,
      'moneda': moneda,
      'porcentaje_impuesto_defecto': porcentajeImpuestoDefecto,
      'terminos_condiciones_factura': terminosCondicionesFactura,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory PerfilTaller.fromMap(Map<String, dynamic> map) {
    return PerfilTaller(
      id: map['id'] as String,
      usuarioAdministradorId: map['usuario_administrador_id'] as String,
      nombreTaller: map['nombre_taller'] as String? ?? 'Mi Taller',
      logoUrl: map['logo_url'] as String?,
      telefono: map['telefono'] as String?,
      direccion: map['direccion'] as String?,
      ciudad: map['ciudad'] as String?,
      moneda: map['moneda'] as String? ?? 'COP',
      porcentajeImpuestoDefecto: (map['porcentaje_impuesto_defecto'] as num?)?.toDouble() ?? 0.0,
      terminosCondicionesFactura: map['terminos_condiciones_factura'] as String?,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at'] as String) 
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at'] as String) 
          : DateTime.now(),
    );
  }
}
