import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';

/// Barra horizontal de chips de categoría con scroll horizontal.
///
/// Permite filtrar la lista de repuestos por categoría.
/// El chip seleccionado se resalta con color de acento.
class CategoryFilter extends StatelessWidget {
  final CategoriaRepuesto? selectedCategory;
  final bool stockBajoActive;
  final int stockBajoCount;
  final ValueChanged<CategoriaRepuesto?> onCategorySelected;
  final VoidCallback onStockBajoToggle;

  const CategoryFilter({
    super.key,
    required this.selectedCategory,
    required this.stockBajoActive,
    required this.stockBajoCount,
    required this.onCategorySelected,
    required this.onStockBajoToggle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
        children: [
          // Chip de alerta de stock bajo
          _buildStockBajoChip(),
          const SizedBox(width: 8),

          // Separador visual
          Container(
            width: 1,
            height: 28,
            margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
            color: AppTheme.surfaceBorder,
          ),
          const SizedBox(width: 8),

          // Chips de categorías
          ...CategoriaRepuesto.values.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildCategoryChip(cat),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockBajoChip() {
    final isActive = stockBajoActive;
    return GestureDetector(
      onTap: onStockBajoToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.warningSurface : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isActive
                ? AppTheme.warning.withOpacity(0.5)
                : AppTheme.surfaceBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: isActive ? AppTheme.warning : AppTheme.textTertiary,
            ),
            const SizedBox(width: 6),
            Text(
              'Stock Bajo',
              style: TextStyle(
                color: isActive ? AppTheme.warning : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (stockBajoCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(isActive ? 0.3 : 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$stockBajoCount',
                  style: TextStyle(
                    color: isActive
                        ? AppTheme.warning
                        : AppTheme.warning.withOpacity(0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(CategoriaRepuesto cat) {
    final isSelected = selectedCategory == cat;
    return GestureDetector(
      onTap: () => onCategorySelected(cat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primarySurface : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(
            color: isSelected
                ? AppTheme.primary.withOpacity(0.5)
                : AppTheme.surfaceBorder,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cat.icon, style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 6),
            Text(
              cat.label,
              style: TextStyle(
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
