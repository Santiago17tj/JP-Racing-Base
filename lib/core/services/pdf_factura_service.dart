import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:moto_taller_app/core/services/pdf_web_helper_stub.dart'
    if (dart.library.html) 'package:moto_taller_app/core/services/pdf_web_helper.dart';
import 'package:moto_taller_app/data/models/cliente.dart';
import 'package:moto_taller_app/data/models/orden_item.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/data/models/vehiculo.dart';
import 'package:moto_taller_app/data/models/perfil_taller.dart';
import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'package:moto_taller_app/core/dominio/reglas_orden.dart';

class PdfFacturaService {
  static String buildInvoiceFileName(String numeroOrden) {
    final safe = numeroOrden
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'factura_${safe.isEmpty ? 'orden' : safe}.pdf';
  }

  static Future<String> generarFacturaPdf({
    required OrdenMantenimiento orden,
    required Cliente cliente,
    required Vehiculo vehiculo,
    required List<OrdenItem> items,
    PerfilTaller? taller,
    bool preview = true,
  }) async {
    final bytes = await construirFacturaBytes(
      orden: orden,
      cliente: cliente,
      vehiculo: vehiculo,
      items: items,
      taller: taller,
    );

    final fileName = orden.esCotizacion
        ? 'cotizacion_${orden.numeroOrden.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}.pdf'
        : buildInvoiceFileName(orden.numeroOrden);

    if (kIsWeb) {
      await openPdfInNewTab(bytes, fileName);
      return fileName;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);

    if (preview) {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: fileName,
      );
    }
    return file.path;
  }

  /// Construye el PDF de la factura y devuelve sus bytes, sin tocar disco.
  /// Separado de [generarFacturaPdf] para poder verificarlo en pruebas.
  static Future<Uint8List> construirFacturaBytes({
    required OrdenMantenimiento orden,
    required Cliente cliente,
    required Vehiculo vehiculo,
    required List<OrdenItem> items,
    PerfilTaller? taller,
    bool comprimir = true,
  }) async {
    final pdf = pw.Document(compress: comprimir);

    // Carga de logo dinámico o fallback
    pw.ImageProvider? logoImage;
    if (taller?.logoUrl != null && taller!.logoUrl!.isNotEmpty) {
      try {
        logoImage = await networkImage(taller.logoUrl!);
      } catch (e) {
        debugPrint('Error cargando logo de red para PDF: $e');
      }
    }

    if (logoImage == null) {
      try {
        final logoBytes = await rootBundle
            .load('Imagenes/ChatGPT Image 24 jun 2026, 01_34_18 p.m..png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (e) {
        debugPrint('Error cargando logo por defecto: $e');
      }
    }

    // Los conceptos de mano de obra ya están sumados en orden.costoManoObra;
    // sus items solo existen para que salgan detallados en la tabla.
    final subtotalRepuestos = ReglasOrden.subtotalRepuestos(items);
    final totalManoObra = orden.costoManoObra;

    final porcentajeImpuesto = taller?.porcentajeImpuestoDefecto ?? 0.0;
    // El IVA solo se calcula sobre la mano de obra: los repuestos se venden con
    // el impuesto ya incluido en el precio de venta.
    final impuestoManoObra =
        ReglasOrden.impuesto(totalManoObra, porcentajeImpuesto);
    final subtotalGeneral = subtotalRepuestos + totalManoObra;
    final total = ReglasOrden.total(
      subtotalRepuestos: subtotalRepuestos,
      costoManoObra: totalManoObra,
      porcentajeImpuesto: porcentajeImpuesto,
    );
    final symbol = taller?.moneda == 'USD'
        ? r'u$s'
        : taller?.moneda == 'EUR'
            ? '€'
            : r'$';

    // Ubicación del taller tomada de Ajustes (dirección y/o ciudad).
    final ubicacionTaller = [taller?.direccion, taller?.ciudad]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(', ');

    // Términos configurados en Ajustes; si no hay, se usa la garantía estándar.
    final terminos = (taller?.terminosCondicionesFactura ?? '')
            .trim()
            .isNotEmpty
        ? taller!.terminosCondicionesFactura!.trim()
        : 'Garantía de 30 días en reparaciones y mano de obra. Todo repuesto instalado cuenta con la garantía directa del fabricante.';

    // Una cotización no es una factura: se rotula distinto.
    final esCotizacion = orden.esCotizacion;
    final tituloDocumento = esCotizacion ? 'COTIZACIÓN' : 'FACTURA DE SERVICIO';
    final etiquetaTotal = esCotizacion ? 'TOTAL COTIZADO:' : 'TOTAL A PAGAR:';

    // Fecha del documento: la de entrega si ya se entregó, para que una
    // reimpresión no cambie la fecha de la factura.
    final fechaDocumento = orden.fechaEntrega ?? DateTime.now();

    // Paleta de colores Premium
    final primaryColor =
        PdfColor.fromHex('#0F172A'); // Azul grisáceo muy oscuro
    final accentColor =
        PdfColor.fromHex('#3B82F6'); // Azul de contraste (Primary Light)
    final neutralLight = PdfColor.fromHex('#F8FAFC'); // Fondo gris claro
    final neutralDark = PdfColor.fromHex('#334155'); // Texto secundario

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Página ${context.pageNumber} de ${context.pagesCount}',
            style: pw.TextStyle(fontSize: 7, color: neutralDark),
          ),
        ),
        build: (context) {
          return [
            // ── ENCABEZADO PRINCIPAL ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 55,
                      height: 55,
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(10),
                        image: pw.DecorationImage(
                            image: logoImage!, fit: pw.BoxFit.cover),
                      ),
                    ),
                    pw.SizedBox(width: 12),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                            taller?.nombreTaller.isNotEmpty == true
                                ? taller!.nombreTaller.toUpperCase()
                                : 'MOTO TALLER',
                            style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: primaryColor)),
                        pw.Text('Servicio técnico y repuestos',
                            style:
                                pw.TextStyle(fontSize: 9, color: neutralDark)),
                        if (ubicacionTaller.isNotEmpty)
                          pw.Text(ubicacionTaller,
                              style: pw.TextStyle(
                                  fontSize: 8, color: neutralDark)),
                        if (taller?.telefono != null)
                          pw.Text('Tel: ${taller!.telefono!}',
                              style: pw.TextStyle(
                                  fontSize: 8, color: neutralDark)),
                      ],
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: pw.BoxDecoration(
                          color: accentColor,
                          borderRadius: pw.BorderRadius.circular(5)),
                      child: pw.Text(tituloDocumento,
                          style: const pw.TextStyle(
                              color: PdfColors.white,
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Nº ${orden.numeroOrden}',
                        style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: primaryColor)),
                    pw.Text(
                        'Fecha: ${fechaDocumento.toLocal().toString().split(' ')[0]}',
                        style: pw.TextStyle(fontSize: 8, color: neutralDark)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Divider(thickness: 0.8, color: PdfColor.fromHex('#E2E8F0')),
            pw.SizedBox(height: 12),

            // ── DETALLES DE CLIENTE Y VEHÍCULO ──
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Columna Cliente
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('CLIENTE',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: accentColor)),
                      pw.SizedBox(height: 4),
                      pw.Text(cliente.nombreCompleto,
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor)),
                      pw.Text(
                          '${cliente.tipoDocumento.label}: ${cliente.numeroDocumento}',
                          style: pw.TextStyle(fontSize: 8, color: neutralDark)),
                      pw.Text('Teléfono: ${cliente.telefono}',
                          style: pw.TextStyle(fontSize: 8, color: neutralDark)),
                      if (cliente.direccion != null &&
                          cliente.direccion!.isNotEmpty)
                        pw.Text('Dirección: ${cliente.direccion}',
                            style:
                                pw.TextStyle(fontSize: 8, color: neutralDark)),
                      if (cliente.email != null && cliente.email!.isNotEmpty)
                        pw.Text('Email: ${cliente.email}',
                            style:
                                pw.TextStyle(fontSize: 8, color: neutralDark)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 24),
                // Columna Vehículo
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('VEHÍCULO / MOTOCICLETA',
                          style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: accentColor)),
                      pw.SizedBox(height: 4),
                      pw.Text('${vehiculo.marca} ${vehiculo.modelo}',
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor)),
                      pw.Text('Placa: ${vehiculo.placaPatente}',
                          style: pw.TextStyle(fontSize: 8, color: neutralDark)),
                      pw.Text(
                          'Año: ${vehiculo.anio} | KM: ${orden.kilometrajeIngreso} km',
                          style: pw.TextStyle(fontSize: 8, color: neutralDark)),
                      if (vehiculo.color != null)
                        pw.Text('Color: ${vehiculo.color}',
                            style:
                                pw.TextStyle(fontSize: 8, color: neutralDark)),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 18),

            // ── TABLA DE DETALLES (ITEMS / REPUESTOS) ──
            pw.Text('DETALLE DE CONCEPTOS Y REPUESTOS UTILIZADOS',
                style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: accentColor)),
            pw.SizedBox(height: 6),
            pw.Table(
              border: const pw.TableBorder(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                horizontalInside:
                    pw.BorderSide(color: PdfColors.grey200, width: 0.5),
              ),
              columnWidths: const {
                0: pw.FlexColumnWidth(3.2), // Descripción
                1: pw.FlexColumnWidth(0.8), // Cantidad
                2: pw.FlexColumnWidth(1.1), // Precio Unitario
                3: pw.FlexColumnWidth(1.1), // Subtotal
              },
              children: [
                // Cabecera de la Tabla (se repite en cada página)
                pw.TableRow(
                  repeat: true,
                  decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: const pw.BorderRadius.vertical(
                          top: pw.Radius.circular(4))),
                  children: [
                    pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 5),
                        child: pw.Text('Descripción / Repuesto',
                            style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8))),
                    pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 5),
                        child: pw.Text('Cant.',
                            style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8),
                            textAlign: pw.TextAlign.center)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 5),
                        child: pw.Text('Precio Unit.',
                            style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8),
                            textAlign: pw.TextAlign.right)),
                    pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            horizontal: 6, vertical: 5),
                        child: pw.Text('Subtotal',
                            style: const pw.TextStyle(
                                color: PdfColors.white,
                                fontWeight: pw.FontWeight.bold,
                                fontSize: 8),
                            textAlign: pw.TextAlign.right)),
                  ],
                ),
                // Filas de Repuestos e items
                ...items.map((item) {
                  return pw.TableRow(
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(item.descripcion,
                              style: const pw.TextStyle(fontSize: 8))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text('${item.cantidad}',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.center)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              '$symbol${CurrencyFormatter.format(item.precioUnitario).replaceAll("\$", "")}',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.right)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                              '$symbol${CurrencyFormatter.format(item.subtotal).replaceAll("\$", "")}',
                              style: const pw.TextStyle(fontSize: 8),
                              textAlign: pw.TextAlign.right)),
                    ],
                  );
                }),
                // Fila vacía si no hay repuestos
                if (items.isEmpty)
                  pw.TableRow(
                    children: [
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text(
                              'No se utilizaron repuestos adicionales',
                              style: const pw.TextStyle(
                                  fontSize: 8,
                                  fontStyle: pw.FontStyle.italic))),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('-', textAlign: pw.TextAlign.center)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('-', textAlign: pw.TextAlign.right)),
                      pw.Padding(
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Text('-', textAlign: pw.TextAlign.right)),
                    ],
                  ),
              ],
            ),
            pw.SizedBox(height: 16),

            // ── RESUMEN DE TOTALES ──
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Notas y observaciones
                pw.Expanded(
                  flex: 1,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Observaciones:',
                          style: pw.TextStyle(
                              fontSize: 7,
                              fontWeight: pw.FontWeight.bold,
                              color: neutralDark)),
                      if (orden.diagnostico != null &&
                          orden.diagnostico!.trim().isNotEmpty)
                        pw.Text('Diagnóstico: ${orden.diagnostico!.trim()}',
                            style:
                                pw.TextStyle(fontSize: 7, color: neutralDark)),
                      if (orden.notasMecanico != null &&
                          orden.notasMecanico!.isNotEmpty)
                        pw.Text('Notas: ${orden.notasMecanico}',
                            style:
                                pw.TextStyle(fontSize: 7, color: neutralDark)),
                      pw.SizedBox(height: 4),
                      pw.Text(terminos,
                          style: pw.TextStyle(fontSize: 7, color: neutralDark)),
                    ],
                  ),
                ),
                pw.SizedBox(width: 32),
                // Bloque de Totales
                pw.Container(
                  width: 180,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: neutralLight,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Mano de obra:',
                              style: const pw.TextStyle(fontSize: 8)),
                          pw.Text(
                              '$symbol${CurrencyFormatter.format(totalManoObra).replaceAll("\$", "")}',
                              style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                              porcentajeImpuesto > 0.0
                                  ? 'Repuestos (IVA incl.):'
                                  : 'Repuestos:',
                              style: const pw.TextStyle(fontSize: 8)),
                          pw.Text(
                              '$symbol${CurrencyFormatter.format(subtotalRepuestos).replaceAll("\$", "")}',
                              style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                      if (porcentajeImpuesto > 0.0) ...[
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Subtotal:',
                                style: const pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text(
                                '$symbol${CurrencyFormatter.format(subtotalGeneral).replaceAll("\$", "")}',
                                style: const pw.TextStyle(
                                    fontSize: 8,
                                    fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(
                                'IVA ${porcentajeImpuesto.toStringAsFixed(1)}% (mano de obra):',
                                style: const pw.TextStyle(fontSize: 8)),
                            pw.Text(
                                '$symbol${CurrencyFormatter.format(impuestoManoObra).replaceAll("\$", "")}',
                                style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ],
                      pw.SizedBox(height: 4),
                      pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                      pw.SizedBox(height: 3),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(etiquetaTotal,
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryColor)),
                          pw.Text(
                              '$symbol${CurrencyFormatter.format(total).replaceAll("\$", "")}',
                              style: pw.TextStyle(
                                  fontSize: 9,
                                  fontWeight: pw.FontWeight.bold,
                                  color: primaryColor)),
                        ],
                      ),
                      if (orden.montoPagado > 0) ...[
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Monto Abonado:',
                                style: const pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.green700,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text(
                                '$symbol${CurrencyFormatter.format(orden.montoPagado).replaceAll("\$", "")}',
                                style: const pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.green700,
                                    fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('SALDO PENDIEN.:',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    color: orden.saldoPendiente > 0
                                        ? PdfColors.red700
                                        : PdfColors.green700,
                                    fontWeight: pw.FontWeight.bold)),
                            pw.Text(
                                '$symbol${CurrencyFormatter.format(orden.saldoPendiente).replaceAll("\$", "")}',
                                style: pw.TextStyle(
                                    fontSize: 8,
                                    color: orden.saldoPendiente > 0
                                        ? PdfColors.red700
                                        : PdfColors.green700,
                                    fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }
}
