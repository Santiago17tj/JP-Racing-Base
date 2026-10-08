import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
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
    if (repuesto.stockCritico)    return AppTheme.error;
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


  @override
  Widget build(BuildContext context) {
    final cat = repuesto.categoria;
    final textos = Theme.of(context).textTheme;
    final pideAtencion = repuesto.stockBajo;

    // Diseño de etiqueta de estante: a la izquierda las unidades, grandes y del
    // color de su estado, separadas por una línea punteada como de etiqueta
    // desprendible; a la derecha qué es y cuánto vale. Se lee de un vistazo y
    // caben el doble de repuestos por pantalla que con la tarjeta anterior.
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppTheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          side: BorderSide(
            color: pideAtencion
                ? _stockColor.withValues(alpha: 0.45)
                : AppTheme.surfaceBorder,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mantener pulsado abre el ajuste libre, igual que antes.
                GestureDetector(
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    _mostrarDialogoAjuste(context);
                  },
                  child: Container(
                    width: 76,
                    color: _stockBgColor,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${repuesto.stockActual}',
                            style: (textos.headlineMedium ??
                                    const TextStyle())
                                .copyWith(
                              color: _stockColor,
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _stockLabel,
                            style: TextStyle(
                              color: _stockColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        Text(
                          'mín. ${repuesto.stockMinimo}',
                          style: TextStyle(
                            color: _stockColor.withValues(alpha: 0.7),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const _LineaPunteada(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            // Sin `Spacer`: con él, categoría y referencia se
                            // quedaban con un tercio del ancho cada una.
                            Expanded(
                              child: Row(
                                children: [
                            Icon(cat.iconData,
                                size: 13, color: AppTheme.textTertiary),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                cat.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Text('  ·  ',
                                style:
                                    TextStyle(color: AppTheme.textTertiary)),
                            Flexible(
                              child: Text(
                                repuesto.codigoInterno,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                tooltip: 'Editar repuesto',
                                icon: const Icon(Icons.edit_outlined,
                                    color: AppTheme.textTertiary),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  onEdit();
                                },
                              ),
                            ),
                          ],
                        ),
                        Text(
                          repuesto.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: (textos.titleMedium ?? const TextStyle())
                              .copyWith(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            height: 1.15,
                          ),
                        ),
                        if (repuesto.marcaRepuesto != null &&
                            repuesto.marcaRepuesto!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              repuesto.marcaRepuesto!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ),
                        const SizedBox(height: 10),
                        // Se encoge el precio, nunca se corta: una cifra de
                        // dinero recortada se lee mal y nadie nota el dígito
                        // que falta.
                        Row(
                          children: [
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  CurrencyFormatter.format(
                                      repuesto.precioVenta),
                                  maxLines: 1,
                                  style: (textos.titleLarge ??
                                          const TextStyle())
                                      .copyWith(
                                    color: AppTheme.primaryLight,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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
                            _StockBtn(
                              icon: Icons.tune_rounded,
                              color: AppTheme.textSecondary,
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
                  ),
                ),
              ],
            ),
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
          width: 38, height: 38,
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
            size: 19,
            color: active ? widget.color : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Línea vertical punteada entre las unidades y el resto de la etiqueta.
class _LineaPunteada extends StatelessWidget {
  const _LineaPunteada();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 1,
      child: CustomPaint(painter: _PintorPunteado()),
    );
  }
}

class _PintorPunteado extends CustomPainter {
  const _PintorPunteado();

  @override
  void paint(Canvas canvas, Size size) {
    final pincel = Paint()
      ..color = AppTheme.surfaceBorder
      ..strokeWidth = 1;
    const trazo = 4.0, hueco = 3.0;
    for (var y = 0.0; y < size.height; y += trazo + hueco) {
      canvas.drawLine(Offset(0.5, y), Offset(0.5, y + trazo), pincel);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
