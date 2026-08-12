import 'dart:io';

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

/// Contrato entre lo que la app escribe y el esquema del SQLite del teléfono.
///
/// El gemelo de `contrato_esquema_nube_test.dart`, para el otro lado. Existe
/// porque el 12/08/2026 aparecieron dos bugs de la misma clase, y los dos solo
/// se manifestaban en **instalaciones nuevas**:
///
///   · `ordenes_mantenimiento` se creaba sin `monto_pagado`, `saldo_pendiente`
///     ni `estado_pago`. Solo se añadían en la migración a la versión 6, así
///     que un teléfono recién instalado no podía guardar un pago.
///   · `clientes` se creaba sin `digito_verificacion`, `regimen_fiscal` ni
///     `codigo_municipio_dane`, los campos de facturación DIAN.
///
/// Los dos pasaron desapercibidos porque en un teléfono que *actualiza* desde
/// una versión anterior las columnas sí existen —las pone el ALTER TABLE— y las
/// pruebas manuales se hicieron siempre sobre bases actualizadas.
///
/// Lee el `CREATE TABLE` del código fuente, así que no necesita una base real.
void main() {
  const rutaFuente = 'lib/data/database/database_helper.dart';
  final helper = DatabaseHelper.instance;

  late Map<String, Set<String>> columnasCreadas;

  setUpAll(() {
    final fuente = File(rutaFuente).readAsStringSync();

    // Cada bloque `CREATE TABLE [IF NOT EXISTS] nombre ( ... )`.
    final bloques = RegExp(
      r'CREATE TABLE (?:IF NOT EXISTS )?(\w+)\s*\(([^;]*?)\)\s*\n\s*''',
      dotAll: true,
    );

    columnasCreadas = {};
    for (final m in bloques.allMatches(fuente)) {
      final tabla = m.group(1)!;
      final cuerpo = m.group(2)!;
      final columnas = <String>{};
      for (final linea in cuerpo.split(',')) {
        final limpia = linea.trim();
        if (limpia.isEmpty) continue;
        // Saltar las restricciones de tabla, que no son columnas.
        final primera = limpia.split(RegExp(r'\s+')).first.toUpperCase();
        if (primera == 'FOREIGN' || primera == 'PRIMARY' || primera == 'UNIQUE') {
          continue;
        }
        final nombre = limpia.split(RegExp(r'\s+')).first;
        if (RegExp(r'^\w+$').hasMatch(nombre)) columnas.add(nombre);
      }
      columnasCreadas[tabla] = columnas;
    }
  });

  test('se pudieron leer los CREATE TABLE del código', () {
    // Si la expresión deja de funcionar, las pruebas de abajo pasarían vacías.
    expect(columnasCreadas.keys, containsAll(<String>[
      'clientes',
      'vehiculos',
      'inventario_repuestos',
      'ordenes_mantenimiento',
      'orden_items',
      'orden_abonos',
      'historial_stock',
      'registro_caja',
      'perfil_taller',
    ]));
    expect(columnasCreadas['clientes']!.length, greaterThan(10));
  });

  test('las columnas de los dos bugs del 12/08/2026 están en el CREATE', () {
    // Anclaje explícito: si alguien las quita del CREATE TABLE y las deja solo
    // en la migración, esta prueba lo dice por su nombre en vez de fallar con
    // un mensaje genérico. Fue el bug que dejó al cliente sin poder guardar
    // pagos en un teléfono recién instalado.
    expect(columnasCreadas['ordenes_mantenimiento'],
        containsAll(['monto_pagado', 'saldo_pendiente', 'estado_pago']));
    expect(
        columnasCreadas['clientes'],
        containsAll([
          'digito_verificacion',
          'regimen_fiscal',
          'codigo_municipio_dane',
        ]));
  });

  void verificar(String tabla, Map<String, dynamic> mapaDelModelo) {
    final escritas = helper.prepararParaLocal(mapaDelModelo).keys.toSet();
    final existentes = columnasCreadas[tabla]!;
    final faltantes = escritas.difference(existentes);

    expect(
      faltantes,
      isEmpty,
      reason: 'La app escribe en `$tabla` columnas que el CREATE TABLE no '
          'crea: $faltantes.\nEn un teléfono recién instalado eso lanza '
          '«no such column» y el dato se pierde. Añádelas al CREATE TABLE, no '
          'solo a la migración: quien instala de cero nunca pasa por ella.',
    );
  }

  group('lo que la app escribe existe en el SQLite del teléfono', () {
    test('clientes — con los campos de la DIAN', () {
      verificar(
        'clientes',
        Cliente(
          tallerId: 'taller-1',
          nombre: 'Johan',
          apellido: 'Parada',
          tipoDocumento: TipoDocumento.nit,
          numeroDocumento: '901234567',
          digitoVerificacion: '3',
          telefono: '3001234567',
          ciudad: 'Bucaramanga',
        ).toMap(),
      );
    });

    test('ordenes_mantenimiento — con el estado de pago', () {
      verificar(
        'ordenes_mantenimiento',
        OrdenMantenimiento(
          tallerId: 'taller-1',
          numeroOrden: 'OT-00001',
          clienteId: 'cliente-1',
          vehiculoId: 'vehiculo-1',
          tipoServicio: 'Mantenimiento',
          kilometrajeIngreso: 15000,
        ).toMap(),
      );
    });

    test('vehiculos', () {
      verificar(
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
      verificar(
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

    test('orden_items — aquí sí se guarda el subtotal', () {
      // A diferencia de la nube, donde es GENERATED ALWAYS, en SQLite el
      // subtotal es una columna normal y la app la escribe.
      verificar(
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
      verificar(
        'orden_abonos',
        Abono(ordenId: 'orden-1', monto: 50000, metodoPago: 'efectivo').toMap(),
      );
    });

    test('historial_stock — con los nombres locales, no los de la nube', () {
      verificar(
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
      verificar(
        'registro_caja',
        RegistroCaja(
          tallerId: 'taller-1',
          tipo: 'ingreso',
          monto: 100000,
          concepto: 'Pago de Orden #OT-00001',
        ).toMap(),
      );
    });

    test('perfil_taller', () {
      verificar(
        'perfil_taller',
        PerfilTaller(
          usuarioAdministradorId: 'usuario-1',
          nombreTaller: 'JP.RACING.315',
          ciudad: 'Bucaramanga',
        ).toMap(),
      );
    });
  });

  group('las columnas que añade la migración también están en el CREATE', () {
    // La regla que se rompió dos veces: si una columna solo aparece en un
    // ALTER TABLE, quien instala de cero se queda sin ella para siempre.
    late Set<String> columnasDeMigracion;

    setUpAll(() {
      final fuente = File(rutaFuente).readAsStringSync();
      columnasDeMigracion = {
        for (final m in RegExp(
                r'ALTER TABLE (\w+) ADD COLUMN (\w+)')
            .allMatches(fuente))
          '${m.group(1)}.${m.group(2)}'
      };
    });

    test('lo que repara _columnasExigidas también está en el CREATE', () {
      // `_repararColumnasFaltantes` arregla bases ya existentes; el CREATE
      // TABLE es para las nuevas. Si las dos listas se separan, vuelve el bug:
      // una instalación nueva sin la columna y sin migración que la añada.
      final fuente = File(rutaFuente).readAsStringSync();
      final bloque = RegExp(
              r'_columnasExigidas = \{(.*?)\n  \};', dotAll: true)
          .firstMatch(fuente);
      expect(bloque, isNotNull,
          reason: 'No se encontró _columnasExigidas: ¿le cambiaron el nombre?');

      // Pares tabla → columnas, tal como los declara el mapa.
      final texto = bloque!.group(1)!;
      final tablas = RegExp(r"'(\w+)': \{([^}]*)\}", dotAll: true);
      var comprobadas = 0;
      for (final t in tablas.allMatches(texto)) {
        final tabla = t.group(1)!;
        for (final c in RegExp(r"'(\w+)':").allMatches(t.group(2)!)) {
          comprobadas++;
          expect(columnasCreadas[tabla], contains(c.group(1)),
              reason: '`$tabla.${c.group(1)}` se repara con ALTER pero no está '
                  'en el CREATE TABLE: una instalación nueva se queda sin ella.');
        }
      }
      expect(comprobadas, greaterThan(5),
          reason: 'La expresión que lee _columnasExigidas dejó de funcionar.');
    });

    test('ninguna columna vive solo en una migración', () {
      final huerfanas = <String>[];
      for (final entrada in columnasDeMigracion) {
        final partes = entrada.split('.');
        final tabla = partes[0];
        final columna = partes[1];
        final creadas = columnasCreadas[tabla];
        if (creadas == null) continue;
        if (!creadas.contains(columna)) huerfanas.add(entrada);
      }
      expect(huerfanas, isEmpty,
          reason: 'Estas columnas se añaden con ALTER TABLE pero no están en el '
              'CREATE TABLE, así que faltan en toda instalación nueva: '
              '$huerfanas');
    });
  });
}
