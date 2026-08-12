import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/repuesto.dart';
import '../../data/providers/inventario_provider.dart';
import '../widgets/repuesto_card.dart';
import '../widgets/category_filter.dart';
import '../widgets/escaner_codigo_barras_dialog.dart';
import 'detalle_repuesto_sheet.dart';
import 'agregar_repuesto_screen.dart';
import 'venta_rapida_screen.dart';

/// Pantalla Principal de la Gestión de Repuestos del Inventario.
class InventarioScreen extends StatefulWidget {
  const InventarioScreen({super.key});

  @override
  State<InventarioScreen> createState() => _InventarioScreenState();
}

class _InventarioScreenState extends State<InventarioScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventarioProvider>().cargarRepuestos();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ── Navegación ────────────────────────────────────────────────────────────

  Future<void> _abrirEscaner() async {
    HapticFeedback.mediumImpact();
    final result = await showDialog<Repuesto>(
      context: context,
      builder: (context) => const EscanerCodigoBarrasDialog(),
    );
    if (result != null && mounted) {
      _verDetalleRepuesto(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Código escaneado: ${result.codigoInterno} (${result.nombre})')),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _verDetalleRepuesto(Repuesto repuesto) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      builder: (context) => DetalleRepuestoSheet(
        repuesto: repuesto,
        provider: context.read<InventarioProvider>(),
      ),
    );
  }

  /// Abre la pantalla de creación de repuesto.
  Future<void> _abrirFormularioNuevo() async {
    HapticFeedback.lightImpact();
    final creado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AgregarRepuestoScreen()),
    );
    if (creado == true && mounted) {
      context.read<InventarioProvider>().cargarRepuestos();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
            SizedBox(width: 8),
            Text('Repuesto creado con éxito'),
          ]),
        ),
      );
    }
  }

  /// Abre la pantalla de edición pasando el repuesto existente.
  Future<void> _abrirFormularioEdicion(Repuesto repuesto) async {
    HapticFeedback.lightImpact();
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AgregarRepuestoScreen(repuestoAEditar: repuesto),
      ),
    );
    if (guardado == true && mounted) {
      context.read<InventarioProvider>().cargarRepuestos();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
            const SizedBox(width: 8),
            Text('${repuesto.nombre} actualizado'),
          ]),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventarioProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario de Repuestos'),
        actions: [
          // Botón venta rápida
          IconButton(
            icon: const Icon(Icons.flash_on_rounded, color: AppTheme.primaryLight),
            tooltip: 'Venta Rápida de Mostrador',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const VentaRapidaScreen()),
            ),
          ),
          // Botón agregar nuevo repuesto
          IconButton(
            icon: const Icon(Icons.add_circle_rounded, color: AppTheme.success),
            tooltip: 'Agregar nuevo repuesto',
            onPressed: _abrirFormularioNuevo,
          ),
          // Botón refrescar
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            tooltip: 'Actualizar lista',
            onPressed: () {
              HapticFeedback.lightImpact();
              provider.cargarRepuestos();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderPanel(provider),
          _buildQuickStats(provider),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppTheme.spacingMd, AppTheme.spacingSm,
                AppTheme.spacingMd, AppTheme.spacingSm),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: provider.buscar,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o código interno...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textTertiary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppTheme.textTertiary),
                        onPressed: () {
                          _searchController.clear();
                          provider.buscar('');
                          _searchFocusNode.unfocus();
                        },
                      )
                    : null,
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
          CategoryFilter(
            selectedCategory: provider.categoriaFiltro,
            stockBajoActive: provider.soloStockBajo,
            stockBajoCount: provider.totalStockBajo,
            onCategorySelected: provider.filtrarPorCategoria,
            onStockBajoToggle: provider.toggleStockBajo,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Expanded(child: _buildListContent(provider)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirEscaner,
        icon: const Icon(Icons.barcode_reader, color: Colors.white, size: 20),
        label: const Text(
          'Escáner',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryLight,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
      ),
    );
  }

  Widget _buildHeaderPanel(InventarioProvider provider) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd, AppTheme.spacingMd,
          AppTheme.spacingMd, AppTheme.spacingSm),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primarySurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.storefront_rounded,
                color: AppTheme.primaryLight, size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Operación del taller',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryLight)),
                SizedBox(height: 2),
                Text('Control de stock, rotación y repuestos críticos',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: provider.totalStockBajo > 0
                  ? AppTheme.warningSurface
                  : AppTheme.successSurface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              provider.totalStockBajo > 0
                  ? '${provider.totalStockBajo} en revisión'
                  : 'Stock estable',
              style: TextStyle(
                color: provider.totalStockBajo > 0
                    ? AppTheme.warning
                    : AppTheme.success,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(InventarioProvider provider) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      margin: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd, AppTheme.spacingSm,
          AppTheme.spacingMd, AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.surfaceBorder, width: 1),
      ),
      child: Row(
        children: [
          Expanded(
              child: _statItem('TOTAL REPUESTOS', '${provider.totalRepuestos}',
                  valueColor: AppTheme.primaryLight)),
          const SizedBox(width: 12),
          Expanded(
              child: _statItem('VALOR TOTAL',
                  CurrencyFormatter.format(provider.valorInventario),
                  valueColor: AppTheme.primaryLight)),
          const SizedBox(width: 12),
          Expanded(
              child: _statItem('SIN STOCK', '${provider.sinStock}',
                  valueColor:
                      provider.sinStock > 0 ? AppTheme.error : AppTheme.success)),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textTertiary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: valueColor ?? AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildListContent(InventarioProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.repuestos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.inventory_2_outlined,
                  size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: AppTheme.spacingMd),
              const Text('No se encontraron repuestos',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: AppTheme.spacingXs),
              const Text(
                'Intenta cambiar los filtros o agrega tu primer repuesto.',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              ElevatedButton.icon(
                onPressed: _abrirFormularioNuevo,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: const Text('Agregar repuesto',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary),
              ),
              if (provider.busqueda.isNotEmpty ||
                  provider.categoriaFiltro != null ||
                  provider.soloStockBajo) ...[
                const SizedBox(height: AppTheme.spacingSm),
                TextButton(
                  onPressed: provider.limpiarFiltros,
                  child: const Text('Limpiar filtros'),
                ),
              ]
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      itemCount: provider.repuestos.length,
      itemBuilder: (context, index) {
        final repuesto = provider.repuestos[index];
        return RepuestoCard(
          key: ValueKey(repuesto.id),
          repuesto: repuesto,
          index: index,
          onTap: () => _verDetalleRepuesto(repuesto),
          onEdit: () => _abrirFormularioEdicion(repuesto),
          onIncrement: () => provider.incrementarStock(repuesto.id),
          onDecrement: () => provider.decrementarStock(repuesto.id),
          onAjustarStock: (delta, motivo) => provider.ajustarStock(
            repuestoId: repuesto.id,
            delta: delta,
            motivo: motivo,
          ),
        );
      },
    );
  }
}
