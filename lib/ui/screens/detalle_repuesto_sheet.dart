import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/repuesto.dart';
import '../../data/models/historial_stock.dart';
import '../../data/providers/inventario_provider.dart';

/// Modal deslizante que muestra el detalle y log de auditoría de un repuesto.
class DetalleRepuestoSheet extends StatelessWidget {
  final Repuesto repuesto;
  final InventarioProvider provider;

  const DetalleRepuestoSheet({
    super.key,
    required this.repuesto,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: FutureBuilder<List<HistorialStock>>(
        future: provider.obtenerHistorial(repuesto.id),
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return ListView(
                controller: scrollController,
                children: [
                  _buildHeader(),
                  const Divider(color: AppTheme.surfaceBorder, height: 24),
                  _buildGeneralInfo(),
                  const SizedBox(height: AppTheme.spacingMd),
                  _buildPricesCard(),
                  const SizedBox(height: AppTheme.spacingLg),
                  _buildStockHistoryHeader(),
                  const SizedBox(height: AppTheme.spacingSm),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.spacingLg),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (logs.isEmpty)
                    _buildEmptyHistory()
                  else
                    ...logs.map((log) => _buildHistoryItem(log)),
                  const SizedBox(height: AppTheme.spacingXl),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                repuesto.categoria.icon + ' ' + repuesto.categoria.label.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.primaryLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                repuesto.nombre,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      repuesto.codigoInterno,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (repuesto.numeroParte != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      'P/N: ${repuesto.numeroParte}',
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (repuesto.descripcion != null && repuesto.descripcion!.isNotEmpty) ...[
          const Text(
            'DESCRIPCIÓN',
            style: TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            repuesto.descripcion!,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
        ],
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                'MARCA',
                repuesto.marcaRepuesto ?? 'Genérica',
              ),
            ),
            Expanded(
              child: _buildInfoItem(
                'UBICACIÓN',
                repuesto.ubicacionAlmacen ?? 'No asignada',
              ),
            ),
            Expanded(
              child: _buildInfoItem(
                'UNIDAD',
                repuesto.unidadMedida,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPricesCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'COSTO',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '\$${repuesto.precioCosto.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PRECIO VENTA',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '\$${repuesto.precioVenta.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppTheme.primaryLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.successSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Column(
              children: [
                Text(
                  '+${repuesto.margenGanancia.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: AppTheme.success,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'MARGEN',
                  style: TextStyle(
                    color: AppTheme.success,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStockHistoryHeader() {
    return const Row(
      children: [
        Icon(
          Icons.history_rounded,
          color: AppTheme.textSecondary,
          size: 18,
        ),
        SizedBox(width: 8),
        Text(
          'Historial de Stock (Auditoría)',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyHistory() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'No hay movimientos registrados para este repuesto.',
          style: TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryItem(HistorialStock log) {
    final format = DateFormat('dd MMM yyyy, hh:mm a');
    final String label = log.tipoMovimiento.label;
    final Color color = log.tipoMovimiento.value == 'ENTRADA'
        ? AppTheme.success
        : log.tipoMovimiento.value == 'SALIDA'
            ? AppTheme.error
            : AppTheme.warning;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.motivo ?? 'Ajuste de inventario',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  format.format(log.createdAt),
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${log.tipoMovimiento.value == 'SALIDA' ? '-' : '+'}${log.cantidad}',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Stock: ${log.stockAnterior} → ${log.stockPosterior}',
                style: const TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 9,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
