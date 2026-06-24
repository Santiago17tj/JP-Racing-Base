import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../data/models/repuesto.dart';

/// Tarjeta de repuesto para la lista de inventario.
///
/// Muestra de forma scannable: nombre, código, categoría, precio y stock.
/// Incluye indicadores visuales de stock bajo/crítico y botones +/−.
class RepuestoCard extends StatelessWidget {
  final Repuesto repuesto;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onTap;
  final int index;

  const RepuestoCard({
    super.key,
    required this.repuesto,
    required this.onIncrement,
    required this.onDecrement,
    required this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context) {
    final stockPriority = repuesto.stockCritico
        ? 'CRÍTICO'
        : repuesto.stockBajo
            ? 'REVISAR'
            : 'OK';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(
            color: repuesto.stockCritico
                ? AppTheme.error.withOpacity(0.35)
                : repuesto.stockBajo
                    ? AppTheme.warning.withOpacity(0.35)
                    : AppTheme.surfaceBorder,
            width: 1.1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: _buildHeader()),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: repuesto.stockCritico
                          ? AppTheme.errorSurface
                          : repuesto.stockBajo
                              ? AppTheme.warningSurface
                              : AppTheme.successSurface,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      stockPriority,
                      style: TextStyle(
                        color: repuesto.stockCritico
                            ? AppTheme.error
                            : repuesto.stockBajo
                                ? AppTheme.warning
                                : AppTheme.success,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                repuesto.nombre,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (repuesto.marcaRepuesto != null) ...[
                const SizedBox(height: 4),
                Text(
                  repuesto.marcaRepuesto!,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: AppTheme.spacingSm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  repuesto.descripcion?.isNotEmpty == true ? repuesto.descripcion! : 'Repuesto de servicio y mantenimiento',
                  style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final cat = repuesto.categoria;
    return Row(
      children: [
        // Badge de categoría
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _getCategoryColor().withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _getCategoryColor().withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                cat.icon,
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(width: 4),
              Text(
                cat.label,
                style: TextStyle(
                  color: _getCategoryColor(),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Código interno
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.qr_code_2_rounded,
                size: 12,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(width: 4),
              Text(
                repuesto.codigoInterno,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'P. VENTA',
                  style: TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '\$${repuesto.precioVenta.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _buildStockControls(context),
      ],
    );
  }

  Widget _buildStockControls(BuildContext context) {
    final Color stockColor = repuesto.stockCritico
        ? AppTheme.error
        : repuesto.stockBajo
            ? AppTheme.warning
            : AppTheme.success;

    final Color stockBgColor = repuesto.stockCritico
        ? AppTheme.errorSurface
        : repuesto.stockBajo
            ? AppTheme.warningSurface
            : AppTheme.successSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón −
        _QuickActionButton(
          icon: Icons.remove_rounded,
          onPressed: repuesto.stockActual > 0
              ? () {
                  HapticFeedback.lightImpact();
                  onDecrement();
                }
              : null,
          color: AppTheme.error,
        ),

        const SizedBox(width: 8),

        // Indicador de stock
        Container(
          constraints: const BoxConstraints(minWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: stockBgColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: stockColor.withOpacity(0.4),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '${repuesto.stockActual}',
                style: TextStyle(
                  color: stockColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                repuesto.stockCritico
                    ? '¡AGOTADO!'
                    : repuesto.stockBajo
                        ? 'BAJO'
                        : 'EN STOCK',
                style: TextStyle(
                  color: stockColor.withOpacity(0.8),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Botón +
        _QuickActionButton(
          icon: Icons.add_rounded,
          onPressed: () {
            HapticFeedback.lightImpact();
            onIncrement();
          },
          color: AppTheme.success,
        ),
      ],
    );
  }

  Color _getCategoryColor() {
    switch (repuesto.categoria) {
      case CategoriaRepuesto.frenos:
        return const Color(0xFFEF4444);
      case CategoriaRepuesto.motor:
        return const Color(0xFFF97316);
      case CategoriaRepuesto.electrico:
        return const Color(0xFFFACC15);
      case CategoriaRepuesto.transmision:
        return const Color(0xFF8B5CF6);
      case CategoriaRepuesto.suspension:
        return const Color(0xFF6366F1);
      case CategoriaRepuesto.carroceria:
        return const Color(0xFF14B8A6);
      case CategoriaRepuesto.llantas:
        return const Color(0xFF64748B);
      case CategoriaRepuesto.lubricantes:
        return const Color(0xFFA855F7);
      case CategoriaRepuesto.filtros:
        return const Color(0xFF06B6D4);
      case CategoriaRepuesto.accesorios:
        return const Color(0xFFEC4899);
      case CategoriaRepuesto.otros:
        return const Color(0xFF94A3B8);
    }
  }
}

/// Botón circular para acciones rápidas de stock (+/−).
class _QuickActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const _QuickActionButton({
    required this.icon,
    required this.onPressed,
    required this.color,
  });

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => _controller.forward() : null,
      onTapUp: isEnabled
          ? (_) {
              _controller.reverse();
              widget.onPressed!();
            }
          : null,
      onTapCancel: isEnabled ? () => _controller.reverse() : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isEnabled
                ? widget.color.withOpacity(0.15)
                : AppTheme.surfaceLight,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            border: Border.all(
              color: isEnabled
                  ? widget.color.withOpacity(0.3)
                  : AppTheme.surfaceBorder,
              width: 1,
            ),
          ),
          child: Icon(
            widget.icon,
            size: 18,
            color: isEnabled ? widget.color : AppTheme.textTertiary,
          ),
        ),
      ),
    );
  }
}
