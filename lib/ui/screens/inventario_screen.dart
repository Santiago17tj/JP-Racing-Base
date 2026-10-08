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
        title: const Text('Inventario'),
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
          _buildQuickStats(provider),
          _buildHeaderPanel(provider),
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
        icon: const Icon(Icons.barcode_reader, size: 20),
        label: const Text('Escáner'),
      ),
    );
  }

  /// Franja de aviso: cuántos repuestos están bajo el mínimo. Tocarla filtra
  /// la lista para ver solo esos.
  Widget _buildHeaderPanel(InventarioProvider provider) {
    final bajos = provider.totalStockBajo;
    final color = bajos > 0 ? AppTheme.warning : AppTheme.success;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd, AppTheme.spacingSm, AppTheme.spacingMd, 0),
      child: Material(
        color: bajos > 0 ? AppTheme.warningSurface : AppTheme.successSurface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: bajos > 0 ? provider.toggleStockBajo : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                    bajos > 0
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_outline_rounded,
                    color: color,
                    size: 18),
                const SizedBox(width: 10),
                Text(
                  bajos > 0 ? '$bajos en revisión' : 'Stock estable',
                  style: TextStyle(
                      color: color, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                if (bajos > 0) ...[
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text('· bajo el mínimo',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                  ),
                  Icon(Icons.chevron_right_rounded, color: color, size: 20),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tablero de bodega: cuántos repuestos hay, cuánto valen y, en la barra,
  /// qué parte está bien, baja o agotada.
  Widget _buildQuickStats(InventarioProvider provider) {
    final repuestos = provider.repuestos;
    final agotados = provider.sinStock;
    final bajos =
        repuestos.where((r) => r.stockBajo && r.stockActual > 0).length;
    final bien = repuestos.length - agotados - bajos;
    final textos = Theme.of(context).textTheme;

    Widget cifra(String valor, String etiqueta, {Color? color}) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              maxLines: 1,
              style: (textos.titleLarge ?? const TextStyle()).copyWith(
                color: color ?? AppTheme.textPrimary,
                fontSize: 26,
                height: 1.05,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );
    }

    Widget separador() => Container(
          width: 1,
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: AppTheme.surfaceBorder,
        );

    Widget tramo(int cantidad, Color color) => cantidad == 0
        ? const SizedBox.shrink()
        : Expanded(flex: cantidad, child: Container(color: color));

    Widget leyenda(int cantidad, String texto, Color color) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text('$cantidad $texto',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 12)),
          ],
        );

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd, AppTheme.spacingSm, AppTheme.spacingMd, 0),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              cifra('${provider.totalRepuestos}', 'REPUESTOS'),
              separador(),
              Expanded(
                child: cifra(
                  CurrencyFormatter.format(provider.valorInventario),
                  'VALOR EN BODEGA',
                  color: AppTheme.primaryLight,
                ),
              ),
              separador(),
              cifra('$agotados', 'SIN STOCK',
                  color: agotados > 0 ? AppTheme.error : AppTheme.success),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: repuestos.isEmpty
                  ? Container(color: AppTheme.surfaceLight)
                  : Row(
                      children: [
                        tramo(bien, AppTheme.success),
                        tramo(bajos, AppTheme.warning),
                        tramo(agotados, AppTheme.error),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              leyenda(bien, 'bien', AppTheme.success),
              leyenda(bajos, bajos == 1 ? 'bajo' : 'bajos', AppTheme.warning),
              leyenda(agotados, agotados == 1 ? 'agotado' : 'agotados',
                  AppTheme.error),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListContent(InventarioProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.repuestos.isEmpty) {
      // Scrollable: en un teléfono pequeño, con el buscador y los filtros
      // arriba, a este mensaje le faltaban 31 px y se recortaba el botón.
      return SingleChildScrollView(
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
      // Margen abajo para que el botón «Escáner» no tape el último repuesto.
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd, 0, AppTheme.spacingMd, 96),
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
