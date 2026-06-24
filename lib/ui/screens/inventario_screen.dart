import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../data/models/repuesto.dart';
import '../../data/providers/inventario_provider.dart';
import '../widgets/repuesto_card.dart';
import '../widgets/category_filter.dart';
import '../widgets/escaner_simulado_dialog.dart';
import 'detalle_repuesto_sheet.dart';

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
    // Cargar repuestos al iniciar la pantalla
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

  /// Muestra el modal simulado de escaneo de código de barras
  Future<void> _abrirEscaner() async {
    HapticFeedback.mediumImpact();
    final result = await showDialog<Repuesto>(
      context: context,
      builder: (context) => const EscanerSimuladoDialog(),
    );

    if (result != null && mounted) {
      // Si escaneó exitosamente, abre el detalle del repuesto de inmediato
      _verDetalleRepuesto(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Código escaneado: ${result.codigoInterno} (${result.nombre})'),
              ),
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventarioProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario de Repuestos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
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
            padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingSm, AppTheme.spacingMd, AppTheme.spacingSm),
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

      // ── Botón Flotante para Escáner Simulado ──
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
      margin: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingMd, AppTheme.spacingMd, AppTheme.spacingSm),
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
            child: const Icon(Icons.storefront_rounded, color: AppTheme.primaryLight, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Operación del taller', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primaryLight)),
                const SizedBox(height: 2),
                Text('Control de stock, rotación y repuestos críticos', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: provider.totalStockBajo > 0 ? AppTheme.warningSurface : AppTheme.successSurface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              provider.totalStockBajo > 0 ? '${provider.totalStockBajo} en revisión' : 'Stock estable',
              style: TextStyle(
                color: provider.totalStockBajo > 0 ? AppTheme.warning : AppTheme.success,
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
      margin: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingSm, AppTheme.spacingMd, AppTheme.spacingSm),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.surfaceBorder, width: 1),
      ),
      child: Row(
        children: [
          Expanded(child: _buildStatItem('TOTAL REPUESTOS', '${provider.totalRepuestos}', valueColor: AppTheme.primaryLight)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatItem('VALOR TOTAL', '\$${provider.valorInventario.toStringAsFixed(0)}', valueColor: AppTheme.primaryLight)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatItem('SIN STOCK', '${provider.sinStock}', valueColor: provider.sinStock > 0 ? AppTheme.error : AppTheme.success)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {Color? valueColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textTertiary,
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
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
              const Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: AppTheme.spacingMd),
              const Text(
                'No se encontraron repuestos',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXs),
              const Text(
                'Intenta cambiar los filtros o el término de búsqueda.',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (provider.busqueda.isNotEmpty ||
                  provider.categoriaFiltro != null ||
                  provider.soloStockBajo) ...[
                const SizedBox(height: AppTheme.spacingMd),
                TextButton(
                  onPressed: provider.limpiarFiltros,
                  child: const Text('Limpiar todos los filtros'),
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
          onIncrement: () => provider.incrementarStock(repuesto.id),
          onDecrement: () => provider.decrementarStock(repuesto.id),
          onTap: () => _verDetalleRepuesto(repuesto),
        );
      },
    );
  }
}
