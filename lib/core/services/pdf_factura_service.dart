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
    final logoBytes = await rootBundle
        .load('Imagenes/ChatGPT Image 24 jun 2026, 01_34_18 p.m..png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    final subtotalRepuestos =
        items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    final total = orden.costoManoObra + subtotalRepuestos;

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: 70,
                    height: 70,
                    child: pw.Image(logoImage, fit: pw.BoxFit.cover),
                  ),
                  pw.SizedBox(width: 16),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('MOTO TALLER',
                            style: pw.TextStyle(
                                fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Servicio técnico y repuestos',
                            style: const pw.TextStyle(fontSize: 12)),
                        pw.SizedBox(height: 6),
                        pw.Text('Factura de servicio',
                            style: pw.TextStyle(
                                fontSize: 16, fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text('Orden: ${orden.numeroOrden}'),
              pw.Text(
                  'Fecha: ${DateTime.now().toLocal().toString().split('.')[0]}'),
              pw.Text('Cliente: ${cliente.nombreCompleto}'),
              pw.Text(
                  'Vehículo: ${vehiculo.marca} ${vehiculo.modelo} - ${vehiculo.placaPatente}'),
              pw.Text('Kilometraje: ${orden.kilometrajeIngreso} km'),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              ...items
                  .map((item) => pw.Row(
                        children: [
                          pw.Expanded(child: pw.Text(item.descripcion)),
                          pw.Text(
                              '${item.cantidad} x \$${item.precioUnitario.toStringAsFixed(2)}'),
                        ],
                      ))
                  .toList(),
              if (items.isEmpty) pw.Text('Sin items registrados'),
              pw.SizedBox(height: 12),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Mano de obra'),
                  pw.Text('\$${orden.costoManoObra.toStringAsFixed(2)}'),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal repuestos'),
                  pw.Text('\$${subtotalRepuestos.toStringAsFixed(2)}'),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('\$${total.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
