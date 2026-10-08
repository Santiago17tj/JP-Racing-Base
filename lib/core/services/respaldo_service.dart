import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/database/database_helper.dart';
import '../../core/constants/enums.dart';
import '../../data/models/cliente.dart';
import '../../data/models/orden_mantenimiento.dart';
import '../../data/models/perfil_taller.dart';
import '../../data/models/vehiculo.dart';
import '../dominio/reglas_orden.dart';
import '../utils/currency_formatter.dart';
import 'pdf_web_helper_stub.dart'
    if (dart.library.html) 'pdf_web_helper.dart';

/// Copia de seguridad de todo lo que el taller ha registrado.
///
/// El dueño debe poder llevarse sus datos sin depender de que la cuenta en la
/// nube siga existiendo. Genera dos archivos:
///   · un JSON completo, pensado para restaurar o migrar;
///   · un CSV de órdenes, que se abre en Excel para la contabilidad.
class RespaldoService {
  RespaldoService._();

  static final DatabaseHelper _db = DatabaseHelper.instance;

  /// Versión del formato. Si algún día cambia la estructura, esto permite
  /// saber cómo leer un respaldo viejo.
  static const int versionFormato = 1;

  /// Reúne todos los datos del taller en un mapa serializable.
  static Future<Map<String, dynamic>> construirRespaldo(
      {PerfilTaller? taller}) async {
    final clientes = await _db.getClientes();
    final vehiculos = await _db.getVehiculos();
    final repuestos = await _db.getRepuestos();
    final caja = await _db.getRegistrosCaja();
    final activas = await _db.getOrdenesActivas();
    // Un respaldo debe traer el archivo completo, no la primera página.
    final historial = await _db.getHistorialOrdenes(limite: 100000);

    final ordenes = <OrdenMantenimiento>[...activas, ...historial];

    // Los ítems se piden por orden: son el detalle que da valor a la factura.
    final items = <Map<String, dynamic>>[];
    for (final orden in ordenes) {
      final deLaOrden = await _db.getItemsDeOrden(orden.id);
      items.addAll(deLaOrden.map((i) => i.toMap()));
    }

    return {
      'version_formato': versionFormato,
      'generado_en': DateTime.now().toIso8601String(),
      'taller': taller?.toMap(),
      'clientes': clientes.map((c) => c.toMap()).toList(),
      'vehiculos': vehiculos.map((v) => v.toMap()).toList(),
      'inventario': repuestos.map((r) => r.toMap()).toList(),
      'ordenes': ordenes.map((o) => o.toMap()).toList(),
      'orden_items': items,
      'movimientos_caja': caja.map((m) => m.toMap()).toList(),
      'resumen': {
        'clientes': clientes.length,
        'vehiculos': vehiculos.length,
        'repuestos': repuestos.length,
        'ordenes': ordenes.length,
        'items': items.length,
        'movimientos_caja': caja.length,
      },
    };
  }

  /// Órdenes en CSV, listo para abrir en Excel.
  ///
  /// Las cifras salen **como en la factura**: el total lleva el IVA de la mano
  /// de obra y el saldo se calcula sobre ese total, por [ReglasOrden]. Antes
  /// el total iba sin IVA y el saldo a veces con él y a veces sin él (según
  /// hubiera habido abonos), así que Total − Abonado no daba el Saldo.
  ///
  /// `Fecha entrega` solo se llena en las órdenes **entregadas**: antes también
  /// salía en las «Lista para entrega», y el contador veía una entrega que aún
  /// no había ocurrido. Cliente y placa se buscan por id; si falta alguno, la
  /// celda queda vacía en vez de romper el archivo.
  static String construirCsvOrdenes(
    List<OrdenMantenimiento> ordenes, {
    double porcentajeImpuesto = 0,
    Map<String, Cliente> clientes = const {},
    Map<String, Vehiculo> vehiculos = const {},
  }) {
    String celda(Object? valor) {
      final texto = (valor ?? '').toString().replaceAll('"', '""');
      return '"$texto"';
    }

    // Coma decimal y sin «.0»: con «120000.0» un Excel en español puede leer
    // el punto como separador de miles.
    String numero(double valor) {
      final redondo = (valor * 100).round() / 100;
      return redondo == redondo.roundToDouble()
          ? redondo.toStringAsFixed(0)
          : redondo.toStringAsFixed(2).replaceAll('.', ',');
    }

    final filas = <String>[
      [
        'Numero',
        'Tipo',
        'Estado',
        'Fecha ingreso',
        'Fecha entrega',
        'Cliente',
        'Placa',
        'Mecanico',
        'Kilometraje',
        'Repuestos',
        'Mano de obra',
        'IVA',
        'Total',
        'Abonado',
        'Saldo',
      ].map(celda).join(';'),
    ];

    for (final o in ordenes) {
      final total = o.totalConImpuesto(porcentajeImpuesto);
      filas.add([
        o.numeroOrden,
        o.esCotizacion ? 'Cotizacion' : 'Orden',
        o.estado.label,
        o.fechaIngreso.toIso8601String().split('T').first,
        o.estado == EstadoOrden.entregada
            ? (o.fechaEntrega?.toIso8601String().split('T').first ?? '')
            : '',
        clientes[o.clienteId]?.nombreCompleto ?? '',
        vehiculos[o.vehiculoId]?.placaPatente ?? '',
        o.mecanicoAsignado ?? '',
        o.kilometrajeIngreso,
        numero(o.subtotalRepuestos),
        numero(o.costoManoObra),
        numero(o.impuestoManoObra(porcentajeImpuesto)),
        numero(total),
        numero(o.montoPagado),
        numero(ReglasOrden.saldoPendiente(
            total: total, montoPagado: o.montoPagado)),
      ].map(celda).join(';'));
    }

    return filas.join('\n');
  }

  /// Genera el respaldo y lo entrega al usuario: en el teléfono abre el menú
  /// de compartir (WhatsApp, Drive, correo); en el navegador lo descarga.
  /// Devuelve el resumen de lo exportado.
  static Future<Map<String, dynamic>> exportar({PerfilTaller? taller}) async {
    final datos = await construirRespaldo(taller: taller);
    final json = const JsonEncoder.withIndent('  ').convert(datos);

    final marca = DateTime.now()
        .toIso8601String()
        .replaceAll(RegExp(r'[:.]'), '-')
        .split('T');
    final nombre = 'mecanix_respaldo_${marca.first}.json';

    final bytes = Uint8List.fromList(utf8.encode(json));

    if (kIsWeb) {
      await descargarArchivoWeb(bytes, nombre, 'application/json');
      return datos['resumen'] as Map<String, dynamic>;
    }

    final dir = await getTemporaryDirectory();
    final archivo = File('${dir.path}/$nombre');
    await archivo.writeAsBytes(bytes);

    final resumen = datos['resumen'] as Map<String, dynamic>;
    await SharePlus.instance.share(ShareParams(
      files: [XFile(archivo.path)],
      text: 'Respaldo Mecanix — ${resumen['ordenes']} órdenes, '
          '${resumen['clientes']} clientes. Guárdalo en un lugar seguro.',
    ));
    return resumen;
  }

  /// Exporta solo las órdenes en CSV para llevarlas al contador.
  static Future<int> exportarCsvOrdenes(
      {double porcentajeImpuesto = 0}) async {
    final activas = await _db.getOrdenesActivas();
    final historial = await _db.getHistorialOrdenes(limite: 100000);
    final ordenes = <OrdenMantenimiento>[...activas, ...historial];

    final clientes = {for (final c in await _db.getClientes()) c.id: c};
    final vehiculos = {for (final v in await _db.getVehiculos()) v.id: v};

    final csv = construirCsvOrdenes(ordenes,
        porcentajeImpuesto: porcentajeImpuesto,
        clientes: clientes,
        vehiculos: vehiculos);
    // BOM para que Excel reconozca los acentos.
    final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
    final nombre =
        'mecanix_ordenes_${DateTime.now().toIso8601String().split('T').first}.csv';

    if (kIsWeb) {
      await descargarArchivoWeb(bytes, nombre, 'text/csv');
      return ordenes.length;
    }

    final dir = await getTemporaryDirectory();
    final archivo = File('${dir.path}/$nombre');
    await archivo.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(archivo.path)],
      text: 'Órdenes del taller (${ordenes.length}) — '
          'total facturado: ${CurrencyFormatter.format(ordenes.fold<double>(0, (s, o) => s + o.totalEstimado))}',
    ));
    return ordenes.length;
  }
}
