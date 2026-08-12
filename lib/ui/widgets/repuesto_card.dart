import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../data/models/repuesto.dart';

/// Tarjeta rediseñada de repuesto para la lista de inventario.
///
/// Incluye:
/// - Chip de stock con color condicional (rojo / amarillo / verde)
/// - Botones +/− de ajuste rápido (+1 / -1)
/// - Botón de ajuste personalizado (entrada libre de cantidad y motivo)
/// - Icono de edición (lápiz) que dispara [onEdit]
class RepuestoCard extends StatelessWidget {
  final Repuesto repuesto;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final Future<bool> Function(int delta, String motivo) onAjustarStock;
  final int index;

  const RepuestoCard({
    super.key,
    required this.repuesto,
    required this.onIncrement,
    required this.onDecrement,
    required this.onTap,
    required this.onEdit,
    required this.onAjustarStock,
    this.index = 0,
  });

  // ── Colores del chip de stock ─────────────────────────────────────────────
  Color get _stockColor {
    if (repuesto.stockActual == 0) return AppTheme.error;
    if (repuesto.stockCritico)    return const Color(0xFFEF4444);
    if (repuesto.stockBajo)       return AppTheme.warning;
    return AppTheme.success;
  }

  Color get _stockBgColor {
    if (repuesto.stockActual == 0) return AppTheme.errorSurface;
    if (repuesto.stockCritico)    return AppTheme.errorSurface;
    if (repuesto.stockBajo)       return AppTheme.warningSurface;
    return AppTheme.successSurface;
  }

  String get _stockLabel {
    if (repuesto.stockActual == 0) return 'AGOTADO';
    if (repuesto.stockCritico)    return 'CRÍTICO';
    if (repuesto.stockBajo)       return 'BAJO';
    return 'EN STOCK';
  }

  Color _categoryColor() {
    switch (repuesto.categoria) {
      case CategoriaRepuesto.frenos:       return const Color(0xFFEF4444);
      case CategoriaRepuesto.motor:        return const Color(0xFFF97316);
      case CategoriaRepuesto.electrico:    return const Color(0xFFFACC15);
      case CategoriaRepuesto.transmision:  return const Color(0xFF8B5CF6);
      case CategoriaRepuesto.suspension:   return const Color(0xFF6366F1);
      case CategoriaRepuesto.carroceria:   return const Color(0xFF14B8A6);
      case CategoriaRepuesto.llantas:      return const Color(0xFF64748B);
      case CategoriaRepuesto.lubricantes:  return const Color(0xFFA855F7);
      case CategoriaRepuesto.filtros:      return const Color(0xFF06B6D4);
      case CategoriaRepuesto.accesorios:   return const Color(0xFFEC4899);
      case CategoriaRepuesto.otros:        return const Color(0xFF94A3B8);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cat = repuesto.categoria;
    final catColor = _categoryColor();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: repuesto.stockActual == 0
                ? AppTheme.error.withValues(alpha: 0.45)
                : repuesto.stockCritico
                    ? AppTheme.error.withValues(alpha: 0.3)
                    : repuesto.stockBajo
                        ? AppTheme.warning.withValues(alpha: 0.3)
                        : AppTheme.surfaceBorder,
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── FILA 1: Categoría · SKU · Stock chip · Editar ─────────────
              Row(
                children: [
                  // Categoría
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: catColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: catColor.withValues(alpha: 0.28), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(cat.icon, style: const TextStyle(fontSize: 11)),
                        const SizedBox(width: 4),
                        Text(cat.label,
                            style: TextStyle(color: catColor, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // SKU
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.qr_code_2_rounded, size: 11, color: AppTheme.textTertiary),
                        const SizedBox(width: 3),
                        Text(
                          repuesto.codigoInterno,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Chip de stock
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _stockBgColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _stockColor.withValues(alpha: 0.35), width: 1),
                    ),
                    child: Text(
                      _stockLabel,
                      style: TextStyle(
                        color: _stockColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Botón editar (lápiz)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onEdit();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_rounded, size: 14, color: AppTheme.primaryLight),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // ── FILA 2: Nombre + Marca ─────────────────────────────────────
              Text(
                repuesto.nombre,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (repuesto.marcaRepuesto != null && repuesto.marcaRepuesto!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  repuesto.marcaRepuesto!,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
              if (repuesto.descripcion != null && repuesto.descripcion!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    repuesto.descripcion!,
                    style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // ── FILA 3: Precio · Controles de stock ───────────────────────
              Row(
                children: [
                  // Precio de venta
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('P. VENTA',
                            style: TextStyle(
                                color: AppTheme.textTertiary,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8)),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.format(repuesto.precioVenta),
                          style: const TextStyle(
                              color: AppTheme.primaryLight,
                              fontSize: 17,
                              fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Controles de stock: [−] [NÚMERO / ESTADO] [+] [⚙]
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _StockBtn(
                        icon: Icons.remove_rounded,
                        color: AppTheme.error,
                        enabled: repuesto.stockActual > 0,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onDecrement();
                        },
                      ),
                      const SizedBox(width: 6),
                      // Contador central — tap largo abre ajuste personalizado
                      GestureDetector(
                        onLongPress: () {
                          HapticFeedback.mediumImpact();
                          _mostrarDialogoAjuste(context);
                        },
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 64),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: _stockBgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _stockColor.withValues(alpha: 0.35), width: 1),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '${repuesto.stockActual}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _stockColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              Text(
                                _stockLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _stockColor.withValues(alpha: 0.75),
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      _StockBtn(
                        icon: Icons.add_rounded,
                        color: AppTheme.success,
                        enabled: true,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onIncrement();
                        },
                      ),
                      const SizedBox(width: 6),
                      // Botón de ajuste personalizado (⚙)
                      _StockBtn(
                        icon: Icons.tune_rounded,
                        color: AppTheme.primaryLight,
                        enabled: true,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _mostrarDialogoAjuste(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Diálogo para ajuste libre de stock (entrada/salida/daño/merma).
  void _mostrarDialogoAjuste(BuildContext context) {
    final cantCtrl   = TextEditingController(text: '1');
    final motivoCtrl = TextEditingController();
    int tipoAjuste  = 1; // 1 = entrada, -1 = salida

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: AppTheme.primaryLight, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ajustar Stock — ${repuesto.nombre}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        'Actual: ${repuesto.stockActual}',
                        style: TextStyle(color: _stockColor, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Selector Entrada / Salida
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModal(() => tipoAjuste = 1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: tipoAjuste == 1
                                  ? AppTheme.successSurface
                                  : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: tipoAjuste == 1
                                    ? AppTheme.success
                                    : AppTheme.surfaceBorder,
                                width: 1.5,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.add_circle_rounded, color: AppTheme.success, size: 22),
                                SizedBox(height: 4),
                                Text('ENTRADA', style: TextStyle(color: AppTheme.success, fontSize: 11, fontWeight: FontWeight.w800)),
                                Text('Compra / Devolución', style: TextStyle(color: AppTheme.textTertiary, fontSize: 9)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModal(() => tipoAjuste = -1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: tipoAjuste == -1
                                  ? AppTheme.errorSurface
                                  : AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: tipoAjuste == -1
                                    ? AppTheme.error
                                    : AppTheme.surfaceBorder,
                                width: 1.5,
                              ),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.remove_circle_rounded, color: AppTheme.error, size: 22),
                                SizedBox(height: 4),
                                Text('SALIDA', style: TextStyle(color: AppTheme.error, fontSize: 11, fontWeight: FontWeight.w800)),
                                Text('Daño / Merma / Uso', style: TextStyle(color: AppTheme.textTertiary, fontSize: 9)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Cantidad
                  TextField(
                    controller: cantCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Motivo
                  TextField(
                    controller: motivoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Motivo (opcional)',
                      hintText: 'Ej: Daño en tránsito, Compra proveedor...',
                      prefixIcon: Icon(Icons.notes_rounded),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final cant = int.tryParse(cantCtrl.text) ?? 0;
                        if (cant <= 0) return;
                        final motivo = motivoCtrl.text.trim().isNotEmpty
                            ? motivoCtrl.text.trim()
                            : (tipoAjuste == 1 ? 'Entrada de stock' : 'Salida / ajuste manual');
                        Navigator.pop(ctx);
                        await onAjustarStock(tipoAjuste * cant, motivo);
                      },
                      icon: Icon(
                        tipoAjuste == 1 ? Icons.add_circle_rounded : Icons.remove_circle_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        tipoAjuste == 1 ? 'APLICAR ENTRADA' : 'APLICAR SALIDA',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tipoAjuste == 1 ? AppTheme.success : AppTheme.error,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// Botón circular compacto para acciones rápidas de stock.
class _StockBtn extends StatefulWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _StockBtn({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_StockBtn> createState() => _StockBtnState();
}

class _StockBtnState extends State<_StockBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl  = AnimationController(vsync: this, duration: const Duration(milliseconds: 90));
    _scale = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled;
    return GestureDetector(
      onTapDown:  active ? (_) => _ctrl.forward()   : null,
      onTapUp:    active ? (_) { _ctrl.reverse(); widget.onTap(); } : null,
      onTapCancel: active ? () => _ctrl.reverse()   : null,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 34, height: 34,
          decoration: BoxDecoration(
            color: active
                ? widget.color.withValues(alpha: 0.13)
                : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: active
                  ? widget.color.withValues(alpha: 0.28)
                  : AppTheme.surfaceBorder,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 17,
            color: active ? widget.color : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}
