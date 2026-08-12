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
      (t) => t.value.toUpperCase() == value.toUpperCase(),
      orElse: () => TipoDocumento.cc,
    );
  }
}

/// Régimen Fiscal para DIAN Colombia / Facturación Electrónica.
enum RegimenFiscal {
  noResponsable('no_responsable', 'No Responsable de IVA', '21'),
  responsable('responsable', 'Responsable de IVA', '48');

  const RegimenFiscal(this.value, this.label, this.code);
  final String value;
  final String label;
  final String code;

  static RegimenFiscal fromValue(String? value) {
    if (value == null) return RegimenFiscal.noResponsable;
    return RegimenFiscal.values.firstWhere(
      (r) => r.value == value || r.code == value,
      orElse: () => RegimenFiscal.noResponsable,
    );
  }
}

/// Modelo de datos para un Cliente.
class Cliente {
  final String id;
  final String? tallerId;
  final String nombre;
  final String apellido;
  final TipoDocumento tipoDocumento;
  final String numeroDocumento;
  final String? digitoVerificacion;
  final RegimenFiscal regimenFiscal;
  final String codigoMunicipioDane;
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
    this.tallerId,
    required this.nombre,
    required this.apellido,
    required this.tipoDocumento,
    required this.numeroDocumento,
    this.digitoVerificacion,
    RegimenFiscal? regimenFiscal,
    String? codigoMunicipioDane,
    this.email,
    required this.telefono,
    this.direccion,
    this.ciudad,
    this.notas,
    this.activo = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        regimenFiscal = regimenFiscal ?? RegimenFiscal.noResponsable,
        codigoMunicipioDane = codigoMunicipioDane ?? '68001',
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  String get nombreCompleto => '$nombre $apellido';

  /// Algoritmo oficial DIAN Colombia para calcular el Dígito de Verificación (DV) de un NIT.
  static String? calcularDV(String? nit) {
    if (nit == null || nit.trim().isEmpty) return null;
    final cleanNit = nit.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNit.isEmpty) return null;

    final vpri = [71, 67, 59, 53, 47, 43, 41, 37, 29, 23, 19, 17, 13, 7, 3];
    final z = cleanNit.length;

    if (z > 15) return null;

    int y = 0;
    for (int i = 0; i < z; i++) {
      final x = int.parse(cleanNit[z - 1 - i]);
      y += x * vpri[vpri.length - 1 - i];
    }

    final int yMod = y % 11;
    if (yMod == 0 || yMod == 1) {
      return yMod.toString();
    }
    return (11 - yMod).toString();
  }

  Cliente copyWith({
    String? tallerId,
    String? nombre,
    String? apellido,
    TipoDocumento? tipoDocumento,
    String? numeroDocumento,
    String? digitoVerificacion,
    RegimenFiscal? regimenFiscal,
    String? codigoMunicipioDane,
    String? email,
    String? telefono,
    String? direccion,
    String? ciudad,
    String? notas,
    bool? activo,
  }) {
    return Cliente(
      id: id,
      tallerId: tallerId ?? this.tallerId,
      nombre: nombre ?? this.nombre,
      apellido: apellido ?? this.apellido,
      tipoDocumento: tipoDocumento ?? this.tipoDocumento,
      numeroDocumento: numeroDocumento ?? this.numeroDocumento,
      digitoVerificacion: digitoVerificacion ?? this.digitoVerificacion,
      regimenFiscal: regimenFiscal ?? this.regimenFiscal,
      codigoMunicipioDane: codigoMunicipioDane ?? this.codigoMunicipioDane,
      email: email ?? this.email,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      ciudad: ciudad ?? this.ciudad,
      notas: notas ?? this.notas,
      activo: activo ?? this.activo,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'taller_id': tallerId,
      'nombre': nombre,
      'apellido': apellido,
      'tipo_documento': tipoDocumento.value,
      'numero_documento': numeroDocumento,
      'digito_verificacion': digitoVerificacion,
      'regimen_fiscal': regimenFiscal.value,
      'codigo_municipio_dane': codigoMunicipioDane,
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
      tallerId: map['taller_id'] as String?,
      nombre: map['nombre'] as String? ?? '',
      apellido: map['apellido'] as String? ?? '',
      tipoDocumento: TipoDocumento.fromValue(map['tipo_documento'] as String? ?? 'CC'),
      numeroDocumento: map['numero_documento'] as String? ?? '',
      digitoVerificacion: map['digito_verificacion'] as String?,
      regimenFiscal: RegimenFiscal.fromValue(map['regimen_fiscal'] as String?),
      codigoMunicipioDane: map['codigo_municipio_dane'] as String? ?? '68001',
      email: map['email'] as String?,
      telefono: map['telefono'] as String? ?? '',
      direccion: map['direccion'] as String?,
      ciudad: map['ciudad'] as String?,
      notas: map['notas'] as String?,
      activo: map['activo'] == true || map['activo'] == 1,
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
