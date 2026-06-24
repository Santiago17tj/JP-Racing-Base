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
  }) async {
    final pdf = pw.Document();
    
    // Carga de logo
    final logoBytes = await rootBundle
        .load('Imagenes/ChatGPT Image 24 jun 2026, 01_34_18 p.m..png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final subtotalRepuestos =
        items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    final total = orden.costoManoObra + subtotalRepuestos;

    // Paleta de colores Premium
    final primaryColor = PdfColor.fromHex('#0F172A'); // Azul grisáceo muy oscuro
    final accentColor = PdfColor.fromHex('#3B82F6');  // Azul de contraste (Primary Light)
    final neutralLight = PdfColor.fromHex('#F8FAFC'); // Fondo gris claro
    final neutralDark = PdfColor.fromHex('#334155');  // Texto secundario

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
                          image: pw.DecorationImage(image: logoImage, fit: pw.BoxFit.cover),
                        ),
                      ),
                      pw.SizedBox(width: 12),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('JP RACING', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.Text('Taller de Motos y Repuestos Especializados', style: pw.TextStyle(fontSize: 9, color: neutralDark)),
                          pw.Text('Tel: +57 300 456 7890 | Bogotá, Colombia', style: pw.TextStyle(fontSize: 8, color: neutralDark)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(color: accentColor, borderRadius: pw.BorderRadius.circular(5)),
                        child: pw.Text('FACTURA DE SERVICIO', style: pw.TextStyle(color: PdfColors.white, fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text('Nº ${orden.numeroOrden}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text('Fecha: ${DateTime.now().toLocal().toString().split(' ')[0]}', style: pw.TextStyle(fontSize: 8, color: neutralDark)),
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
                        pw.Text('CLIENTE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accentColor)),
                        pw.SizedBox(height: 4),
                        pw.Text(cliente.nombreCompleto, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text('${cliente.tipoDocumento.label}: ${cliente.numeroDocumento}', style: pw.TextStyle(fontSize: 8, color: neutralDark)),
                        pw.Text('Teléfono: ${cliente.telefono}', style: pw.TextStyle(fontSize: 8, color: neutralDark)),
                        if (cliente.email != null && cliente.email!.isNotEmpty)
                          pw.Text('Email: ${cliente.email}', style: pw.TextStyle(fontSize: 8, color: neutralDark)),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 24),
                  // Columna Vehículo
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('VEHÍCULO / MOTOCICLETA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accentColor)),
                        pw.SizedBox(height: 4),
                        pw.Text('${vehiculo.marca} ${vehiculo.modelo}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text('Placa: ${vehiculo.placaPatente}', style: pw.TextStyle(fontSize: 8, color: neutralDark)),
                        pw.Text('Año: ${vehiculo.anio} | KM: ${orden.kilometrajeIngreso} km', style: pw.TextStyle(fontSize: 8, color: neutralDark)),
                        if (vehiculo.color != null)
                          pw.Text('Color: ${vehiculo.color}', style: pw.TextStyle(fontSize: 8, color: neutralDark)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 18),

              // ── TABLA DE DETALLES (ITEMS / REPUESTOS) ──
              pw.Text('DETALLE DE CONCEPTOS Y REPUESTOS UTILIZADOS', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accentColor)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: const pw.TableBorder(
                  bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
                  horizontalInside: pw.BorderSide(color: PdfColors.grey200, width: 0.5),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3.2), // Descripción
                  1: pw.FlexColumnWidth(0.8), // Cantidad
                  2: pw.FlexColumnWidth(1.1), // Precio Unitario
                  3: pw.FlexColumnWidth(1.1), // Subtotal
                },
                children: [
                  // Cabecera de la Tabla
                  pw.TableRow(
                    decoration: pw.BoxDecoration(color: primaryColor, borderRadius: const pw.BorderRadius.vertical(top: pw.Radius.circular(4))),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.Text('Descripción / Repuesto', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8))),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.Text('Cant.', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.center)),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.Text('Precio Unit.', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.right)),
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5), child: pw.Text('Subtotal', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 8), textAlign: pw.TextAlign.right)),
                    ],
                  ),
                  // Filas de Repuestos
                  ...items.map((item) {
                    return pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(item.descripcion, style: const pw.TextStyle(fontSize: 8))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${item.cantidad}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('\$${item.precioUnitario.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('\$${item.subtotal.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8), textAlign: pw.TextAlign.right)),
                      ],
                    );
                  }).toList(),
                  // Fila vacía si no hay repuestos
                  if (items.isEmpty)
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('No se utilizaron repuestos adicionales', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic))),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('-', textAlign: pw.TextAlign.center)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('-', textAlign: pw.TextAlign.right)),
                        pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('-', textAlign: pw.TextAlign.right)),
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
                        pw.Text('Observaciones:', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: neutralDark)),
                        pw.Text('Garantía de 30 días en reparaciones y mano de obra. Todo repuesto instalado cuenta con la garantía directa del fabricante.', style: pw.TextStyle(fontSize: 7, color: neutralDark)),
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
                            pw.Text('Mano de obra:', style: const pw.TextStyle(fontSize: 8)),
                            pw.Text('\$${orden.costoManoObra.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Repuestos:', style: const pw.TextStyle(fontSize: 8)),
                            pw.Text('\$${subtotalRepuestos.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                        pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                        pw.SizedBox(height: 3),
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('TOTAL A PAGAR:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                            pw.Text('\$${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final fileName = buildInvoiceFileName(orden.numeroOrden);

    if (kIsWeb) {
      final bytes = await pdf.save();
      await openPdfInNewTab(bytes, fileName);
      return fileName;
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }
}
