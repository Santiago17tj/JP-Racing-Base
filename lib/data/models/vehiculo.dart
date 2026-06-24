import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Modelo de datos para un Vehículo (Motocicleta).
class Vehiculo {
  final String id;
  final String clienteId;
  final String placaPatente;
  final String marca;
  final String modelo;
  final int anio;
  final int kilometrajeActual;
  final String? color;
  final String? numeroMotor;
  final String? numeroChasis;
  final String? notas;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  Vehiculo({
    String? id,
    required this.clienteId,
    required this.placaPatente,
    required this.marca,
    required this.modelo,
    required this.anio,
    this.kilometrajeActual = 0,
    this.color,
    this.numeroMotor,
    this.numeroChasis,
    this.notas,
    this.activo = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get descripcionCompleta => '$marca $modelo ($placaPatente)';

  Vehiculo copyWith({
    String? clienteId,
    String? placaPatente,
    String? marca,
    String? modelo,
    int? anio,
    int? kilometrajeActual,
    String? color,
    String? numeroMotor,
    String? numeroChasis,
    String? notas,
    bool? activo,
  }) {
    return Vehiculo(
      id: id,
      clienteId: clienteId ?? this.clienteId,
      placaPatente: placaPatente ?? this.placaPatente,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      anio: anio ?? this.anio,
      kilometrajeActual: kilometrajeActual ?? this.kilometrajeActual,
      color: color ?? this.color,
      numeroMotor: numeroMotor ?? this.numeroMotor,
      numeroChasis: numeroChasis ?? this.numeroChasis,
      notas: notas ?? this.notas,
      activo: activo ?? this.activo,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'placa_patente': placaPatente,
      'marca': marca,
      'modelo': modelo,
      'anio': anio,
      'kilometraje_actual': kilometrajeActual,
      'color': color,
      'numero_motor': numeroMotor,
      'numero_chasis': numeroChasis,
      'notas': notas,
      'activo': activo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory Vehiculo.fromMap(Map<String, dynamic> map) {
    return Vehiculo(
      id: map['id'] as String,
      clienteId: map['cliente_id'] as String,
      placaPatente: map['placa_patente'] as String,
      marca: map['marca'] as String,
      modelo: map['modelo'] as String,
      anio: map['anio'] as int,
      kilometrajeActual: map['kilometraje_actual'] as int,
      color: map['color'] as String?,
      numeroMotor: map['numero_motor'] as String?,
      numeroChasis: map['numero_chasis'] as String?,
      notas: map['notas'] as String?,
      activo: (map['activo'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
