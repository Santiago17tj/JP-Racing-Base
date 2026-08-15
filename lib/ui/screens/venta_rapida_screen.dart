import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/repuesto.dart';
import '../../data/providers/inventario_provider.dart';
import '../../data/providers/ordenes_provider.dart';
import '../../data/providers/sesion_local_provider.dart';
import '../widgets/escaner_codigo_barras_dialog.dart';
import '../widgets/identificar_ia_dialog.dart';

class VentaRapidaScreen extends StatefulWidget {
  const VentaRapidaScreen({super.key});

  @override
  State<VentaRapidaScreen> createState() => _VentaRapidaScreenState();
}

class _VentaRapidaScreenState extends State<VentaRapidaScreen> {
  final List<Map<String, dynamic>> _carrito = [];
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  List<Repuesto> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventarioProvider>().cargarRepuestos();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _buscarRepuesto(String query, List<Repuesto> todos) {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    final q = query.toLowerCase();
    final matches = todos
        .where((r) =>
            r.nombre.toLowerCase().contains(q) ||
            r.codigoInterno.toLowerCase().contains(q))
        .toList();
    setState(() {
      _searchResults = matches;
      _isSearching = true;
    });
  }

  void _agregarAlCarrito(Repuesto repuesto) {
    HapticFeedback.lightImpact();
    final idx = _carrito
        .indexWhere((item) => (item['repuesto'] as Repuesto).id == repuesto.id);
    if (idx != -1) {
      final currentQty = _carrito[idx]['cantidad'] as int;
      if (currentQty < repuesto.stockActual) {
        setState(() {
          _carrito[idx]['cantidad'] = currentQty + 1;
        });
      } else {
        _showError('No hay más stock disponible para este repuesto.');
      }
    } else {
      if (repuesto.stockActual > 0) {
        setState(() {
          _carrito.add({'repuesto': repuesto, 'cantidad': 1});
        });
      } else {
        _showError('El repuesto seleccionado no tiene stock disponible.');
      }
    }
    // Limpiar busqueda
    _searchCtrl.clear();
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
    _searchFocus.unfocus();
  }

  void _actualizarCantidad(int index, int delta) {
    HapticFeedback.lightImpact();
    final item = _carrito[index];
    final repuesto = item['repuesto'] as Repuesto;
    final nuevaCantidad = (item['cantidad'] as int) + delta;

    if (nuevaCantidad <= 0) {
      setState(() {
        _carrito.removeAt(index);
      });
    } else if (nuevaCantidad <= repuesto.stockActual) {
      setState(() {
        _carrito[index]['cantidad'] = nuevaCantidad;
      });
    } else {
      _showError('Límite de stock alcanzado (${repuesto.stockActual} u.)');
    }
  }

  double get _totalVenta {
    return _carrito.fold(0.0, (sum, item) {
      final rep = item['repuesto'] as Repuesto;
      final qty = item['cantidad'] as int;
      return sum + (rep.precioVenta * qty);
    });
  }

  double get _totalCosto {
    return _carrito.fold(0.0, (sum, item) {
      final rep = item['repuesto'] as Repuesto;
      final qty = item['cantidad'] as int;
      return sum + (rep.precioCosto * qty);
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppTheme.error),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppTheme.errorSurface,
      ),
    );
  }

  Future<void> _abrirEscaner() async {
    HapticFeedback.mediumImpact();
    final result = await showDialog<Repuesto>(
      context: context,
      builder: (context) => const EscanerCodigoBarrasDialog(),
    );

    if (result != null && mounted) {
      _agregarAlCarrito(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Repuesto "${result.nombre}" añadido por escaneo'),
          backgroundColor: AppTheme.successSurface,
        ),
      );
    }
  }

  Future<void> _identificarConIa() async {
    HapticFeedback.mediumImpact();
    final result = await showDialog<Repuesto>(
      context: context,
      builder: (context) => const IdentificarIaDialog(),
    );

    if (result != null && mounted) {
      _agregarAlCarrito(result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Repuesto "${result.nombre}" identificado con IA y añadido'),
          backgroundColor: AppTheme.successSurface,
        ),
      );
    }
  }

  Future<void> _procesarVenta() async {
    if (_carrito.isEmpty) return;
    HapticFeedback.mediumImpact();

    final ordenesProvider = context.read<OrdenesProvider>();
    final inventarioProvider = context.read<InventarioProvider>();

    // Mostrar modal premium de procesamiento
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          color: AppTheme.surface,
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primaryLight),
                SizedBox(height: 16),
                Text(
                  'Procesando venta de mostrador...',
                  style: TextStyle(
                      color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final Map<Repuesto, int> itemsMap = {
        for (var item in _carrito)
          item['repuesto'] as Repuesto: item['cantidad'] as int,
      };

      await ordenesProvider.procesarVentaRapida(
        items: itemsMap,
        totalVenta: _totalVenta,
        totalCosto: _totalCosto,
      );

      // Sincronizar stock local en el inventario provider
      await inventarioProvider.cargarRepuestos();

      if (mounted) {
        Navigator.pop(context); // cerrar procesando
        _mostrarExitoDialog();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // cerrar procesando
        _showError('No se pudo procesar la venta: $e');
      }
    }
  }

  void _mostrarExitoDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 28),
            SizedBox(width: 10),
            Text('¡Venta Exitosa!',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'La transacción de mostrador se ha completado correctamente.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              'Total Cobrado: ${CurrencyFormatter.format(_totalVenta)}',
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primaryLight),
            ),
            if (context.read<SesionLocalProvider>().puedeVerFinanzas)
              Text(
                'Ganancia Estimada: ${CurrencyFormatter.format((_totalVenta - _totalCosto))}',
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppTheme.success),
              ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Cerrar dialog
              Navigator.pop(context); // Salir de pantalla Venta Rápida
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Entendido'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventario = context.watch<InventarioProvider>();
    final todosRepuestos = inventario.repuestos;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Venta Rápida de Mostrador'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded,
                color: AppTheme.primaryLight),
            tooltip: 'Escanear Código',
            onPressed: _abrirEscaner,
          ),
          IconButton(
            icon: const Icon(Icons.camera_enhance_rounded,
                color: AppTheme.primaryLight),
            tooltip: 'Identificar con IA',
            onPressed: _identificarConIa,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // En pantallas angostas (celular) el resumen va abajo; en tablet o
          // escritorio se mantiene como panel lateral.
          final esPantallaAncha = constraints.maxWidth >= 700;
          if (esPantallaAncha) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 3, child: _buildPanelCarrito(todosRepuestos)),
                SizedBox(width: 320, child: _buildPanelResumen(lateral: true)),
              ],
            );
          }
          return Column(
            children: [
              Expanded(child: _buildPanelCarrito(todosRepuestos)),
              // Tope de altura para que el resumen nunca desborde en
              // pantallas pequeñas; si no cabe, se desplaza.
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxHeight: constraints.maxHeight * 0.55),
                child: SingleChildScrollView(
                  child: _buildPanelResumen(lateral: false),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Buscador + lista de repuestos agregados a la venta.
  Widget _buildPanelCarrito(List<Repuesto> todosRepuestos) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      child: Column(
        children: [
          // Buscador Premium
          _buildSearchField(todosRepuestos),
          if (_isSearching) ...[
            const SizedBox(height: AppTheme.spacingSm),
            _buildSearchResults(),
          ],
          const SizedBox(height: AppTheme.spacingMd),

          // Título de carrito
          const Row(
            children: [
              Icon(Icons.shopping_bag_outlined,
                  color: AppTheme.textSecondary, size: 18),
              SizedBox(width: 8),
              Text(
                'REPUESTOS A VENDER',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),

          // Lista del Carrito
          Expanded(
            child: _carrito.isEmpty ? _buildEmptyState() : _buildCartList(),
          ),
        ],
      ),
    );
  }

  /// Resumen de la venta y botón de cobro.
  Widget _buildPanelResumen({required bool lateral}) {
    final verFinanzas = context.watch<SesionLocalProvider>().puedeVerFinanzas;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          left: lateral
              ? const BorderSide(color: AppTheme.surfaceBorder, width: 1.2)
              : BorderSide.none,
          top: lateral
              ? BorderSide.none
              : const BorderSide(color: AppTheme.surfaceBorder, width: 1.2),
        ),
      ),
      padding: const EdgeInsets.all(AppTheme.spacingLg),
      child: Column(
        mainAxisSize: lateral ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'RESUMEN DE VENTA',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 1.2,
            ),
          ),
          const Divider(height: 24, color: AppTheme.surfaceBorder),
          const SizedBox(height: 8),
          _buildSummaryRow('Items totales',
              '${_carrito.fold(0, (sum, i) => sum + (i['cantidad'] as int))} u.'),
          const SizedBox(height: 12),
          // El costo y el margen son información del dueño, no del mecánico.
          if (verFinanzas)
            _buildSummaryRow(
                'Valor del Costo', CurrencyFormatter.format(_totalCosto)),
          if (verFinanzas) const SizedBox(height: 12),
          _buildSummaryRow('Impuestos incl.', '\$0.00'),
          if (lateral) const Spacer() else const SizedBox(height: 16),

          // Card de Ganancia Neta Estimada
          if (_carrito.isNotEmpty && verFinanzas)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: AppTheme.success.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.monetization_on_rounded,
                      color: AppTheme.success, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ganancia neta estimada',
                            style: TextStyle(
                                fontSize: 10, color: AppTheme.textSecondary)),
                        Text(
                          '+${CurrencyFormatter.format((_totalVenta - _totalCosto))}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.success,
                              fontSize: 14),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ).animate().fadeIn().scale(delay: 100.ms),

          const SizedBox(height: 20),

          // Gran total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL COBRAR',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.textPrimary)),
              Text(
                CurrencyFormatter.format(_totalVenta),
                style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: AppTheme.primaryLight),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Botón checkout
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _carrito.isEmpty ? null : _procesarVenta,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
              // La etiqueta mide unos 199 px y en el panel lateral de la
              // disposición ancha le quedan unos 197: desbordaba por 2 px en
              // tablet, y por 1 en un teléfono de 320. `FittedBox` la encoge
              // lo justo en vez de recortarla.
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.point_of_sale_rounded, size: 18),
                  SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('REGISTRAR VENTA (PAGADA)',
                          maxLines: 1,
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(List<Repuesto> todos) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: _searchFocus.hasFocus
            ? [
                BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    blurRadius: 10)
              ]
            : [],
      ),
      child: TextField(
        controller: _searchCtrl,
        focusNode: _searchFocus,
        onChanged: (q) => _buscarRepuesto(q, todos),
        decoration: InputDecoration(
          hintText: 'Escriba nombre o código del repuesto para agregar...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _isSearching
              ? Container(
                  width: 250,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          _buscarRepuesto('', todos);
                        },
                      ),
                    ],
                  ),
                )
              : null,
        ),
      ),
    );
  }

  /// Resultados de la búsqueda: se tocan para agregarlos al carrito.
  Widget _buildSearchResults() {
    if (_searchResults.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: AppTheme.cardDecoration,
        child: const Text(
          'Ningún repuesto coincide con la búsqueda.',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: AppTheme.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _searchResults.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, color: AppTheme.surfaceBorder),
        itemBuilder: (context, index) {
          final repuesto = _searchResults[index];
          final sinStock = repuesto.stockActual <= 0;
          return ListTile(
            dense: true,
            enabled: !sinStock,
            onTap: sinStock ? null : () => _agregarAlCarrito(repuesto),
            leading: Icon(
              sinStock
                  ? Icons.remove_shopping_cart_rounded
                  : Icons.add_shopping_cart_rounded,
              color: sinStock ? AppTheme.textTertiary : AppTheme.primaryLight,
              size: 20,
            ),
            title: Text(
              repuesto.nombre,
              style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${repuesto.codigoInterno} · Stock: ${repuesto.stockActual}',
              style: TextStyle(
                fontSize: 11,
                color: sinStock ? AppTheme.error : AppTheme.textSecondary,
              ),
            ),
            trailing: Text(
              CurrencyFormatter.format(repuesto.precioVenta),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    // Scrollable a propósito: en un teléfono pequeño, con el resumen ocupando
    // más de la mitad de la pantalla, a este mensaje le quedaban 50 px menos
    // de los que necesita y se recortaba.
    return SingleChildScrollView(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined,
                size: 48, color: AppTheme.textTertiary.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            const Text(
              'El carrito está vacío',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 4),
            const Text(
              'Escanea un código o busca un repuesto en la parte superior.',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildCartList() {
    return ListView.separated(
      itemCount: _carrito.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _carrito[index];
        final rep = item['repuesto'] as Repuesto;
        final qty = item['cantidad'] as int;

        return Container(
          decoration: AppTheme.cardDecoration,
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd, vertical: 12),
          child: Row(
            children: [
              // Icono/Info repuesto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rep.nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Código: ${rep.codigoInterno}  |  Stock: ${rep.stockActual} u.',
                      style: const TextStyle(
                          color: AppTheme.textTertiary, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Precio
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.format((rep.precioVenta * qty)),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.primaryLight),
                  ),
                  Text(
                    'u. ${CurrencyFormatter.format(rep.precioVenta)}',
                    style: const TextStyle(
                        color: AppTheme.textTertiary, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(width: 16),

              // Controles cantidad
              Row(
                children: [
                  _QtyButton(
                    icon: Icons.remove,
                    onTap: () => _actualizarCantidad(index, -1),
                  ),
                  Container(
                    width: 32,
                    alignment: Alignment.center,
                    child: Text(
                      '$qty',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                  _QtyButton(
                    icon: Icons.add,
                    onTap: () => _actualizarCantidad(index, 1),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style:
                const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: AppTheme.textPrimary)),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppTheme.surfaceBorder),
        ),
        child: Icon(icon, size: 14, color: AppTheme.textPrimary),
      ),
    );
  }
}
