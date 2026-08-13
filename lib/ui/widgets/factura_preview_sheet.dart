import 'package:flutter/material.dart';
import 'package:flutter_email_sender/flutter_email_sender.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_theme.dart';
import '../../core/dominio/reglas_orden.dart';
import '../../core/services/factura_service.dart';
import '../../core/services/pdf_factura_service.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/cliente.dart';
import '../../data/models/orden_item.dart';
import '../../data/models/orden_mantenimiento.dart';
import '../../data/models/vehiculo.dart';
import '../../data/providers/taller_provider.dart';

/// Hoja con la vista previa de la factura y las acciones para enviarla.
class FacturaPreviewSheet extends StatelessWidget {
  final OrdenMantenimiento orden;
  final Cliente cliente;
  final Vehiculo vehiculo;
  final List<OrdenItem> items;

  const FacturaPreviewSheet({
    super.key,
    required this.orden,
    required this.cliente,
    required this.vehiculo,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    // Perfil del taller configurado en Ajustes: alimenta logo, dirección,
    // moneda e impuesto de la factura PDF.
    final taller = context.read<TallerProvider>().taller;
    final porcentajeImpuesto = taller?.porcentajeImpuestoDefecto ?? 0.0;
    final nombreTaller = (taller?.nombreTaller ?? '').trim().isNotEmpty
        ? taller!.nombreTaller.toUpperCase()
        : 'MOTO TALLER';
    final logoUrl = taller?.logoUrl ?? '';
    final documento = orden.esCotizacion ? 'Cotización' : 'Factura';
    final ubicacionTaller = [taller?.direccion, taller?.ciudad]
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(', ');

    // La mano de obra vive en orden.costoManoObra; sus items solo existen
    // para el detalle, por eso no se suman al subtotal de repuestos.
    final subtotalRepuestos = ReglasOrden.subtotalRepuestos(items);
    final impuesto = orden.impuestoManoObra(porcentajeImpuesto);
    final total = orden.costoManoObra + subtotalRepuestos + impuesto;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: AppTheme.primaryLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Factura de servicio',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF121826), Color(0xFF1B2335)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: logoUrl.isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: logoUrl,
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) => Image.asset(
                                      'Imagenes/ChatGPT Image 24 jun 2026, 01_34_18 p.m..png',
                                      width: 64,
                                      height: 64,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'Imagenes/ChatGPT Image 24 jun 2026, 01_34_18 p.m..png',
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(nombreTaller,
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryLight)),
                              const SizedBox(height: 4),
                              const Text('Servicio técnico y repuestos',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13)),
                              if (ubicacionTaller.isNotEmpty)
                                Text(ubicacionTaller,
                                    style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 12)),
                              const SizedBox(height: 6),
                              Text(
                                  orden.esCotizacion
                                      ? 'Cotización'
                                      : 'Factura de servicio',
                                  style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.primaryLight.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(orden.estado.label,
                              style: const TextStyle(
                                  color: AppTheme.primaryLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildFacturaMeta('ORDEN', orden.numeroOrden),
                        _buildFacturaMeta('FECHA',
                            DateTime.now().toLocal().toString().split('.')[0]),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cliente: ${cliente.nombreCompleto}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(
                              'Vehículo: ${vehiculo.marca} ${vehiculo.modelo} - ${vehiculo.placaPatente}',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary)),
                          Text('Kilometraje: ${orden.kilometrajeIngreso} km',
                              style: const TextStyle(
                                  color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    const Divider(color: AppTheme.surfaceBorder),
                    ...items.map((item) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                AppTheme.surfaceLight.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(item.descripcion,
                                      style: const TextStyle(fontSize: 13))),
                              Text(
                                  '${item.cantidad} x ${CurrencyFormatter.format(item.precioUnitario)}',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Sin items registrados',
                            style: TextStyle(color: AppTheme.textTertiary)),
                      ),
                    const Divider(color: AppTheme.surfaceBorder),
                    _buildFacturaTotalRow('Mano de obra', orden.costoManoObra),
                    const SizedBox(height: 6),
                    _buildFacturaTotalRow(
                        porcentajeImpuesto > 0
                            ? 'Subtotal repuestos (IVA incl.)'
                            : 'Subtotal repuestos',
                        subtotalRepuestos),
                    if (impuesto > 0) ...[
                      const SizedBox(height: 6),
                      _buildFacturaTotalRow(
                          'IVA ${porcentajeImpuesto.toStringAsFixed(1)}% (mano de obra)',
                          impuesto),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryLight)),
                          Text(CurrencyFormatter.format(total),
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryLight)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final pdfFile = await PdfFacturaService.generarFacturaPdf(
                        orden: orden,
                        cliente: cliente,
                        vehiculo: vehiculo,
                        items: items,
                        taller: taller,
                        preview: false,
                      );
                      final cuerpoCorreo = FacturaService.buildEmailBody(
                        numeroOrden: orden.numeroOrden,
                        cliente: cliente.nombreCompleto,
                        vehiculo: '${vehiculo.marca} ${vehiculo.modelo}',
                        total: total,
                        items: items.map((item) => item.descripcion).toList(),
                      );

                      final Email email = Email(
                        body: cuerpoCorreo,
                        subject:
                            '$documento - Orden #${orden.numeroOrden} - $nombreTaller',
                        recipients: [cliente.email ?? ''],
                        attachmentPaths: [pdfFile],
                        isHTML: false,
                      );

                      try {
                        await FlutterEmailSender.send(email);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Aplicación de correo abierta correctamente. Presiona enviar.')),
                          );
                        }
                      } on FlutterEmailSenderNotAvailableException {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                  'No hay una aplicación de correo instalada. Configúrala e intenta de nuevo.'),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 6),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al enviar: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.email_rounded),
                    label: const Text('Enviar por correo'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final path = await PdfFacturaService.generarFacturaPdf(
                          orden: orden,
                          cliente: cliente,
                          vehiculo: vehiculo,
                          items: items,
                          taller: taller,
                          preview: false,
                        );
                        await SharePlus.instance.share(ShareParams(
                          files: [XFile(path)],
                          text:
                              '$documento - Orden #${orden.numeroOrden} - $nombreTaller',
                        ));
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error al compartir: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.share_rounded),
                    label: const Text('Compartir (WhatsApp, etc.)'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        await PdfFacturaService.generarFacturaPdf(
                          orden: orden,
                          cliente: cliente,
                          vehiculo: vehiculo,
                          items: items,
                          taller: taller,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Se preparó el PDF para descargar')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('No se pudo generar el PDF: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Descargar PDF'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFacturaMeta(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textTertiary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFacturaTotalRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        Text(CurrencyFormatter.format(value),
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Selector modal para buscar y añadir repuestos a la orden de servicio.
