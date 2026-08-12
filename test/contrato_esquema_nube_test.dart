import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/data/database/database_helper.dart';
import 'package:moto_taller_app/data/models/abono.dart';
import 'package:moto_taller_app/data/models/cliente.dart';
import 'package:moto_taller_app/data/models/historial_stock.dart';
import 'package:moto_taller_app/data/models/orden_item.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/data/models/perfil_taller.dart';
import 'package:moto_taller_app/data/models/registro_caja.dart';
import 'package:moto_taller_app/data/models/repuesto.dart';
import 'package:moto_taller_app/data/models/vehiculo.dart';

/// Contrato entre lo que la app escribe y las columnas que existen de verdad en
/// Supabase.
///
/// Por qué existe: si la app manda una columna que la nube no tiene, PostgREST
/// rechaza **la fila entera**, y ese error caía en un `catch` con `debugPrint`
/// que en release no se ve. Así se perdieron meses de datos sin que nada
/// avisara. Esta prueba convierte esa pérdida silenciosa en un fallo ruidoso
/// en el momento de tocar un modelo.
///
/// Casos reales que habría atajado el mismo día:
///   · `orden_items.subtotal` es GENERATED ALWAYS → enviarla rompe la fila.
///   · `historial_stock` se llama `stock_antes`/`stock_despues` en la nube.
///   · `Cliente` ganó `digito_verificacion`, `regimen_fiscal` y
///     `codigo_municipio_dane` (campos DIAN) y dejó de sincronizar desde el
///     30/07/2026, hasta que se añadieron esas columnas el 11/08/2026.
///
/// ── Cómo regenerar el fixture ────────────────────────────────────────────
/// Contra el proyecto real (`snzqauzmtydcheryfwmd`):
///
///   SELECT table_name, string_agg(column_name, ',' ORDER BY column_name) cols,
///          string_agg(CASE WHEN is_generated='ALWAYS' THEN column_name END, ',') generadas
///   FROM information_schema.columns WHERE table_schema='public'
///   GROUP BY table_name ORDER BY table_name;
///
/// Verificado el 11 de agosto de 2026.
const Map<String, Set<String>> columnasEnLaNube = {
  'clientes': {
    'activo', 'apellido', 'ciudad', 'codigo_municipio_dane', 'created_at',
    'digito_verificacion', 'direccion', 'email', 'id', 'nombre', 'notas',
    'numero_documento', 'regimen_fiscal', 'taller_id', 'telefono',
    'tipo_documento', 'updated_at',
  },
  'historial_stock': {
    'cantidad', 'created_at', 'id', 'motivo', 'orden_id', 'repuesto_id',
    'stock_antes', 'stock_despues', 'tipo_movimiento',
  },
  'inventario_repuestos': {
    'activo', 'categoria', 'codigo_interno', 'created_at', 'descripcion',
    'foto_url', 'id', 'marca_repuesto', 'nombre', 'numero_parte',
    'precio_costo', 'precio_venta', 'stock_actual', 'stock_minimo',
    'subcategoria', 'taller_id', 'ubicacion_almacen', 'unidad_medida',
    'updated_at',
  },
  'orden_abonos': {
    'created_at', 'fecha', 'id', 'metodo_pago', 'monto', 'notas', 'orden_id',
  },
  'orden_items': {
    'cantidad', 'created_at', 'descripcion', 'descuento', 'id', 'orden_id',
    'precio_unitario', 'repuesto_id', 'subtotal',
  },
  'ordenes_mantenimiento': {
    'activo', 'cliente_id', 'costo_mano_obra', 'created_at',
    'descripcion_problema', 'diagnostico', 'es_cotizacion', 'estado',
    'estado_pago', 'fecha_entrega', 'fecha_ingreso', 'fecha_promesa',
    'fotos_estado', 'id', 'kilometraje_ingreso', 'mecanico_asignado',
    'monto_pagado', 'notas_mecanico', 'numero_orden', 'saldo_pendiente',
    'subtotal_repuestos', 'taller_id', 'tipo_servicio', 'total_estimado',
    'updated_at', 'vehiculo_id',
  },
  'perfil_taller': {
    'ciudad', 'created_at', 'direccion', 'id', 'logo_url', 'moneda',
    'nombre_taller', 'porcentaje_impuesto_defecto', 'telefono',
    'terminos_condiciones_factura', 'updated_at', 'usuario_administrador_id',
  },
  'registro_caja': {
    'concepto', 'fecha', 'id', 'monto', 'referencia_id', 'taller_id', 'tipo',
  },
  'vehiculos': {
    'activo', 'anio', 'cliente_id', 'color', 'created_at', 'id',
    'kilometraje', 'kilometraje_actual', 'marca', 'modelo', 'notas',
    'numero_chasis', 'numero_motor', 'placa', 'placa_patente', 'taller_id',
    'updated_at',
  },
};

/// Columnas calculadas por Postgres. Enviarlas hace fallar la inserción.
const Map<String, Set<String>> columnasGeneradas = {
  'orden_items': {'subtotal'},
};

void main() {
  final helper = DatabaseHelper.instance;

  /// Lo que la app realmente manda a Supabase para ese modelo.
  Set<String> loQueEnviaLaApp(Map<String, dynamic> mapaDelModelo) =>
      helper.prepararParaNube(mapaDelModelo).keys.toSet();

  void verificarTabla(String tabla, Map<String, dynamic> mapaDelModelo) {
    final enviadas = loQueEnviaLaApp(mapaDelModelo);
    final existentes = columnasEnLaNube[tabla]!;
    final generadas = columnasGeneradas[tabla] ?? const <String>{};

    final inexistentes = enviadas.difference(existentes);
    expect(
      inexistentes,
      isEmpty,
      reason: 'La app manda a `$tabla` columnas que no existen en la nube: '
          '$inexistentes.\nPostgREST rechaza la fila entera y el dato se queda '
          'solo en el teléfono. Añade la columna en Supabase o quítala en '
          '_prepareToDb.',
    );

    final generadasEnviadas = enviadas.intersection(generadas);
    expect(
      generadasEnviadas,
      isEmpty,
      reason: 'La app manda a `$tabla` columnas GENERATED ALWAYS: '
          '$generadasEnviadas. Postgres rechaza la escritura.',
    );
  }

  group('lo que la app escribe existe en la nube', () {
    test('clientes — incluidos los campos DIAN', () {
      verificarTabla(
        'clientes',
        Cliente(
          tallerId: 'taller-1',
          nombre: 'Luis',
          apellido: 'Tarazona',
          tipoDocumento: TipoDocumento.nit,
          numeroDocumento: '901234567',
          digitoVerificacion: '3',
          telefono: '3001234567',
          ciudad: 'Bucaramanga',
        ).toMap(),
      );
    });

    test('vehiculos', () {
      verificarTabla(
        'vehiculos',
        Vehiculo(
          tallerId: 'taller-1',
          clienteId: 'cliente-1',
          placaPatente: 'ABC12D',
          marca: 'Yamaha',
          modelo: 'FZ 2.0',
          anio: 2020,
        ).toMap(),
      );
    });

    test('inventario_repuestos', () {
      verificarTabla(
        'inventario_repuestos',
        Repuesto(
          tallerId: 'taller-1',
          codigoInterno: 'FRE-001',
          nombre: 'Pastillas de freno',
          categoria: CategoriaRepuesto.frenos,
          precioCosto: 20000,
          precioVenta: 35000,
        ).toMap(),
      );
    });

    test('ordenes_mantenimiento', () {
      verificarTabla(
        'ordenes_mantenimiento',
        OrdenMantenimiento(
          tallerId: 'taller-1',
          numeroOrden: 'OT-00015',
          clienteId: 'cliente-1',
          vehiculoId: 'vehiculo-1',
          tipoServicio: 'Mantenimiento',
          kilometrajeIngreso: 15000,
        ).toMap(),
      );
    });

    test('orden_items — y no manda el subtotal generado', () {
      verificarTabla(
        'orden_items',
        OrdenItem(
          ordenId: 'orden-1',
          repuestoId: 'repuesto-1',
          descripcion: 'Cambio de aceite',
          cantidad: 1,
          precioUnitario: 45000,
        ).toMap(),
      );
    });

    test('orden_abonos', () {
      verificarTabla(
        'orden_abonos',
        Abono(
          ordenId: 'orden-1',
          monto: 50000,
          metodoPago: 'efectivo',
        ).toMap(),
      );
    });

    test('historial_stock — con los nombres que usa la nube', () {
      verificarTabla(
        'historial_stock',
        HistorialStock(
          repuestoId: 'repuesto-1',
          ordenId: 'orden-1',
          tipoMovimiento: TipoMovimiento.salida,
          cantidad: 1,
          stockAnterior: 10,
          stockPosterior: 9,
        ).toMap(),
      );
    });

    test('registro_caja', () {
      verificarTabla(
        'registro_caja',
        RegistroCaja(
          tallerId: 'taller-1',
          tipo: 'ingreso',
          monto: 100000,
          concepto: 'Pago de orden',
        ).toMap(),
      );
    });

    test('perfil_taller', () {
      verificarTabla(
        'perfil_taller',
        PerfilTaller(
          usuarioAdministradorId: 'usuario-1',
          nombreTaller: 'JP Racing',
          ciudad: 'Bucaramanga',
        ).toMap(),
      );
    });
  });

  group('las traducciones de nombres se aplican', () {
    test('historial_stock: stock_anterior → stock_antes', () {
      final enviado = DatabaseHelper.instance.prepararParaNube(
        HistorialStock(
          repuestoId: 'r',
          tipoMovimiento: TipoMovimiento.salida,
          cantidad: 1,
          stockAnterior: 10,
          stockPosterior: 9,
        ).toMap(),
      );
      expect(enviado['stock_antes'], 10);
      expect(enviado['stock_despues'], 9);
      expect(enviado.containsKey('stock_anterior'), isFalse);
      expect(enviado.containsKey('stock_posterior'), isFalse);
    });

    test('vehiculos: placa_patente se copia a placa', () {
      final enviado = DatabaseHelper.instance.prepararParaNube(
        Vehiculo(
          clienteId: 'c',
          placaPatente: 'ABC12D',
          marca: 'Yamaha',
          modelo: 'FZ',
          anio: 2020,
          kilometrajeActual: 15000,
        ).toMap(),
      );
      expect(enviado['placa'], 'ABC12D');
      expect(enviado['kilometraje'], 15000);
    });

    test('ordenes: mecanico_assigned → mecanico_asignado', () {
      final enviado = DatabaseHelper.instance.prepararParaNube(
        OrdenMantenimiento(
          numeroOrden: 'OT-1',
          clienteId: 'c',
          vehiculoId: 'v',
          tipoServicio: 'Mantenimiento',
          kilometrajeIngreso: 0,
          mecanicoAsignado: 'Sebastián',
        ).toMap(),
      );
      expect(enviado['mecanico_asignado'], 'Sebastián');
      expect(enviado.containsKey('mecanico_assigned'), isFalse);
    });
  });
}
