import 'package:uuid/uuid.dart';
import '../../core/constants/enums.dart';

const _uuid = Uuid();

/// Modelo de datos para un repuesto en el inventario.
///
/// Refleja la tabla `inventario_repuestos` del modelo de datos.
/// Usa UUID como identificador para compatibilidad offline-first.
class Repuesto {
  final String id;
  final String codigoInterno;
  final String nombre;
  final String? descripcion;
  final String? fotoUrl;
  final CategoriaRepuesto categoria;
  final String? subcategoria;
  final String? marcaRepuesto;
  final String? numeroParte;
  final int stockActual;
  final int stockMinimo;
  final double precioCosto;
  final double precioVenta;
  final String? ubicacionAlmacen;
  final String unidadMedida;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  Repuesto({
    String? id,
    required this.codigoInterno,
    required this.nombre,
    this.descripcion,
    this.fotoUrl,
    required this.categoria,
    this.subcategoria,
    this.marcaRepuesto,
    this.numeroParte,
    this.stockActual = 0,
    this.stockMinimo = 5,
    required this.precioCosto,
    required this.precioVenta,
    this.ubicacionAlmacen,
    this.unidadMedida = 'unidad',
    this.activo = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// ¿El stock está por debajo del mínimo?
  bool get stockBajo => stockActual <= stockMinimo;

  /// ¿El stock está en estado crítico (0 o menos del 50% del mínimo)?
  bool get stockCritico => stockActual == 0 || stockActual <= (stockMinimo * 0.5).round();

  /// Margen de ganancia calculado.
  double get margenGanancia =>
      precioCosto > 0 ? ((precioVenta - precioCosto) / precioCosto) * 100 : 0;

  /// Nivel de stock como porcentaje del mínimo (0.0 a 1.0+).
  double get nivelStock =>
      stockMinimo > 0 ? stockActual / stockMinimo : (stockActual > 0 ? 2.0 : 0.0);

  /// Crea una copia del repuesto con campos modificados.
  Repuesto copyWith({
    String? codigoInterno,
    String? nombre,
    String? descripcion,
    String? fotoUrl,
    CategoriaRepuesto? categoria,
    String? subcategoria,
    String? marcaRepuesto,
    String? numeroParte,
    int? stockActual,
    int? stockMinimo,
    double? precioCosto,
    double? precioVenta,
    String? ubicacionAlmacen,
    String? unidadMedida,
    bool? activo,
  }) {
    return Repuesto(
      id: id,
      codigoInterno: codigoInterno ?? this.codigoInterno,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      categoria: categoria ?? this.categoria,
      subcategoria: subcategoria ?? this.subcategoria,
      marcaRepuesto: marcaRepuesto ?? this.marcaRepuesto,
      numeroParte: numeroParte ?? this.numeroParte,
      stockActual: stockActual ?? this.stockActual,
      stockMinimo: stockMinimo ?? this.stockMinimo,
      precioCosto: precioCosto ?? this.precioCosto,
      precioVenta: precioVenta ?? this.precioVenta,
      ubicacionAlmacen: ubicacionAlmacen ?? this.ubicacionAlmacen,
      unidadMedida: unidadMedida ?? this.unidadMedida,
      activo: activo ?? this.activo,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  /// Convierte a Map para insertar en SQLite.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo_interno': codigoInterno,
      'nombre': nombre,
      'descripcion': descripcion,
      'foto_url': fotoUrl,
      'categoria': categoria.value,
      'subcategoria': subcategoria,
      'marca_repuesto': marcaRepuesto,
      'numero_parte': numeroParte,
      'stock_actual': stockActual,
      'stock_minimo': stockMinimo,
      'precio_costo': precioCosto,
      'precio_venta': precioVenta,
      'ubicacion_almacen': ubicacionAlmacen,
      'unidad_medida': unidadMedida,
      'activo': activo ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Crea una instancia desde un Map de SQLite.
  factory Repuesto.fromMap(Map<String, dynamic> map) {
    return Repuesto(
      id: map['id'] as String,
      codigoInterno: map['codigo_interno'] as String,
      nombre: map['nombre'] as String,
      descripcion: map['descripcion'] as String?,
      fotoUrl: map['foto_url'] as String?,
      categoria: CategoriaRepuesto.fromValue(map['categoria'] as String),
      subcategoria: map['subcategoria'] as String?,
      marcaRepuesto: map['marca_repuesto'] as String?,
      numeroParte: map['numero_parte'] as String?,
      stockActual: map['stock_actual'] as int,
      stockMinimo: map['stock_minimo'] as int,
      precioCosto: (map['precio_costo'] as num).toDouble(),
      precioVenta: (map['precio_venta'] as num).toDouble(),
      ubicacionAlmacen: map['ubicacion_almacen'] as String?,
      unidadMedida: map['unidad_medida'] as String? ?? 'unidad',
      activo: (map['activo'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  factory Repuesto.fromJson(Map<String, dynamic> json) {
    return Repuesto(
      id: json['id'] as String?,
      codigoInterno: json['codigo_interno'] as String? ?? '',
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      fotoUrl: json['foto_url'] as String?,
      categoria: CategoriaRepuesto.fromValue(json['categoria'] as String? ?? CategoriaRepuesto.otros.value),
      stockActual: (json['stock_actual'] as num?)?.toInt() ?? 0,
      stockMinimo: (json['stock_minimo'] as num?)?.toInt() ?? 5,
      precioCosto: (json['precio_costo'] as num?)?.toDouble() ?? 0,
      precioVenta: (json['precio_venta'] as num?)?.toDouble() ?? 0,
      activo: json['activo'] as bool? ?? true,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
