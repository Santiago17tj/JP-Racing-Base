import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Tipos de documentos de identificación.
enum TipoDocumento {
  cc('CC', 'Cédula de Ciudadanía'),
  nit('NIT', 'NIT'),
  ruc('RUC', 'RUC'),
  dni('DNI', 'DNI'),
  pasaporte('PASAPORTE', 'Pasaporte');

  const TipoDocumento(this.value, this.label);
  final String value;
  final String label;

  static TipoDocumento fromValue(String value) {
    return TipoDocumento.values.firstWhere(
      (t) => t.value == value,
      orElse: () => TipoDocumento.dni,
    );
  }
}

/// Modelo de datos para un Cliente.
class Cliente {
  final String id;
  final String nombre;
  final String apellido;
  final TipoDocumento tipoDocumento;
  final String numeroDocumento;
  final String? email;
  final String telefono;
  final String? direccion;
  final String? ciudad;
  final String? notas;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  Cliente({
    String? id,
    required this.nombre,
    required this.apellido,
    required this.tipoDocumento,
    required this.numeroDocumento,
    this.email,
    required this.telefono,
    this.direccion,
    this.ciudad,
    this.notas,
    this.activo = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get nombreCompleto => '$nombre $apellido';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'tipo_documento': tipoDocumento.value,
      'numero_documento': numeroDocumento,
      'email': email,
      'telefono': telefono,
      'direccion': direccion,
      'ciudad': ciudad,
      'notas': notas,
      'activo': activo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      apellido: map['apellido'] as String,
      tipoDocumento: TipoDocumento.fromValue(map['tipo_documento'] as String),
      numeroDocumento: map['numero_documento'] as String,
      email: map['email'] as String?,
      telefono: map['telefono'] as String,
      direccion: map['direccion'] as String?,
      ciudad: map['ciudad'] as String?,
      notas: map['notas'] as String?,
      activo: (map['activo'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
