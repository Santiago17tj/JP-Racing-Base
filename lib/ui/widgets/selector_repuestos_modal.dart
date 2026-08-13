import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/repuesto.dart';
import '../../data/providers/inventario_provider.dart';

/// Buscador de repuestos del inventario para agregarlos a una orden.
class SelectorRepuestosModal extends StatefulWidget {
  final InventarioProvider inventarioProvider;
  final Future<bool> Function(Repuesto repuesto, int cantidad)
      onRepuestoSelected;

  const SelectorRepuestosModal({
    super.key,
    required this.inventarioProvider,
    required this.onRepuestoSelected,
  });

  @override
  State<SelectorRepuestosModal> createState() => SelectorRepuestosModalState();
}

class SelectorRepuestosModalState extends State<SelectorRepuestosModal> {
  final _searchCtrl = TextEditingController();
  final Map<String, int> _cantidades =
      {}; // Guarda la cantidad digitada para cada repuesto
  bool _procesando = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: AppTheme.spacingMd,
        left: AppTheme.spacingMd,
        right: AppTheme.spacingMd,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingMd,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.add_shopping_cart_rounded,
                  color: AppTheme.primaryLight, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Agregar Repuesto al Servicio',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close_rounded,
                    color: AppTheme.textTertiary),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          TextField(
            controller: _searchCtrl,
            decoration: const InputDecoration(
              hintText: 'Escribe código o nombre del repuesto...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: (text) {
              setState(() {
                widget.inventarioProvider.buscar(text);
              });
            },
          ),
          const SizedBox(height: AppTheme.spacingMd),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: widget.inventarioProvider.repuestos.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text('No hay repuestos activos en inventario',
                          style: TextStyle(color: AppTheme.textTertiary)),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.inventarioProvider.repuestos.length,
                    itemBuilder: (context, index) {
                      final rep = widget.inventarioProvider.repuestos[index];
                      final tieneStock = rep.stockActual > 0;
                      final cantActual = _cantidades[rep.id] ?? 1;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSm),
                          border: Border.all(color: AppTheme.surfaceBorder),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    rep.nombre,
                                    style: TextStyle(
                                      color: tieneStock
                                          ? AppTheme.textPrimary
                                          : AppTheme.textTertiary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'SKU: ${rep.codigoInterno}  |  Stock: ${rep.stockActual}  |  Precio: ${CurrencyFormatter.format(rep.precioVenta)}',
                                    style: const TextStyle(
                                        color: AppTheme.textTertiary,
                                        fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            if (tieneStock) ...[
                              // Controles de cantidad
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove,
                                        size: 16,
                                        color: AppTheme.textSecondary),
                                    onPressed: cantActual > 1
                                        ? () {
                                            setState(() {
                                              _cantidades[rep.id] =
                                                  cantActual - 1;
                                            });
                                          }
                                        : null,
                                  ),
                                  Text('$cantActual',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add,
                                        size: 16,
                                        color: AppTheme.textSecondary),
                                    onPressed: cantActual < rep.stockActual
                                        ? () {
                                            setState(() {
                                              _cantidades[rep.id] =
                                                  cantActual + 1;
                                            });
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: _procesando
                                    ? null
                                    : () async {
                                        // Se capturan antes del `await`: el
                                        // modal puede cerrarse mientras se
                                        // guarda, y entonces este `context` ya
                                        // no sirve. El `mounted` de antes era
                                        // del State, no de este builder: daba
                                        // una falsa sensación de seguridad.
                                        final navigator = Navigator.of(context);
                                        final messenger =
                                            ScaffoldMessenger.of(context);

                                        setState(() => _procesando = true);
                                        HapticFeedback.lightImpact();
                                        final exito =
                                            await widget.onRepuestoSelected(
                                                rep, cantActual);
                                        if (mounted) {
                                          setState(() => _procesando = false);
                                        }

                                        if (exito) {
                                          navigator.pop();
                                          messenger.showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Añadido: ${rep.nombre}')),
                                          );
                                        } else {
                                          messenger.showSnackBar(
                                            const SnackBar(
                                                content: Text(
                                                    'Error al agregar (Verifica stock)')),
                                          );
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6)),
                                ),
                                child: const Icon(Icons.add_rounded, size: 18),
                              ),
                            ] else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                    color: AppTheme.errorSurface,
                                    borderRadius: BorderRadius.circular(4)),
                                child: const Text(
                                  'SIN STOCK',
                                  style: TextStyle(
                                      color: AppTheme.error,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold),
                                ),
                              )
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: AppTheme.spacingMd),
        ],
      ),
    );
  }
}
