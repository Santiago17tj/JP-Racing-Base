import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/registro_caja.dart';
import '../../data/providers/ordenes_provider.dart';
import '../../data/providers/taller_provider.dart';

/// Pantalla del Módulo Contable y Flujo de Caja.
///
/// Muestra métricas de ingresos, costos y ganancias del mes,
/// junto con la lista de movimientos y la opción de registrar transacciones manuales.
class ContabilidadScreen extends StatefulWidget {
  const ContabilidadScreen({super.key});

  @override
  State<ContabilidadScreen> createState() => _ContabilidadScreenState();
}

class _ContabilidadScreenState extends State<ContabilidadScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdenesProvider>().cargarDatos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ordenesProvider = context.watch<OrdenesProvider>();
    final taller = context.watch<TallerProvider>().taller;

    // Obtener símbolo de moneda del taller
    final symbol = taller?.moneda == 'USD'
        ? r'u$s'
        : taller?.moneda == 'EUR'
            ? '€'
            : r'$';
    final formatter = NumberFormat.currency(
        locale: 'es_CO', symbol: '$symbol ', decimalDigits: 0);

    final movimientos = ordenesProvider.movimientosCaja;

    // Calcular métricas
    double ingresosTotales = 0.0;
    double egresosTotales = 0.0;

    for (final mov in movimientos) {
      if (mov.tipo == 'ingreso') {
        ingresosTotales += mov.monto;
      } else {
        egresosTotales += mov.monto;
      }
    }

    final gananciaNeta = ingresosTotales - egresosTotales;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contabilidad & Caja'),
      ),
      body: RefreshIndicator(
        onRefresh: () => ordenesProvider.cargarDatos(),
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            // Banner explicativo estilo Invoice Fly
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              margin: const EdgeInsets.only(bottom: AppTheme.spacingMd),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.auto_awesome_rounded,
                      color: AppTheme.primaryLight),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      'Las órdenes de servicio marcadas como "Entregada" registran automáticamente sus ingresos y egresos de inventario.',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            // ── SECCIÓN DE TARJETAS DE MÉTRICAS (GRID/ROW) ──
            LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth =
                    (constraints.maxWidth - (AppTheme.spacingSm * 2)) / 3;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricCard(
                      titulo: 'Ingresos',
                      monto: formatter.format(ingresosTotales),
                      color: AppTheme.success,
                      icon: Icons.trending_up_rounded,
                      width: cardWidth,
                    ),
                    _buildMetricCard(
                      titulo: 'Costos/Gastos',
                      monto: formatter.format(egresosTotales),
                      color: AppTheme.warning,
                      icon: Icons.trending_down_rounded,
                      width: cardWidth,
                    ),
                    _buildNetProfitCard(
                      monto: formatter.format(gananciaNeta),
                      width: cardWidth,
                    ),
                  ],
                );
              },
            )
                .animate()
                .slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOut),

            const SizedBox(height: AppTheme.spacingLg),

            // ── LISTA DE MOVIMIENTOS RECIENTES ──
            const Text(
              'Últimos Movimientos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            if (movimientos.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_long_rounded,
                        size: 48, color: AppTheme.textTertiary),
                    SizedBox(height: 12),
                    Text(
                      'No hay transacciones registradas',
                      style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Crea una orden y márcala como entregada para ver el flujo de caja.',
                      style:
                          TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: movimientos.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final mov = movimientos[index];
                  final esIngreso = mov.tipo == 'ingreso';

                  return Container(
                    decoration: AppTheme.cardDecoration,
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    child: Row(
                      children: [
                        // Icono circular
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: esIngreso
                                ? AppTheme.success.withValues(alpha: 0.15)
                                : AppTheme.error.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            esIngreso
                                ? Icons.arrow_downward_rounded
                                : Icons.arrow_upward_rounded,
                            color:
                                esIngreso ? AppTheme.success : AppTheme.error,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingMd),
                        // Concepto y fecha
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mov.concepto,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('dd/MM/yyyy • hh:mm a')
                                    .format(mov.fecha),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacingSm),
                        // Monto
                        Text(
                          '${esIngreso ? '+' : '-'} ${formatter.format(mov.monto)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color:
                                esIngreso ? AppTheme.success : AppTheme.error,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_rounded,
                              color: AppTheme.textTertiary, size: 20),
                          onPressed: () =>
                              _editarMovimientoDialog(context, mov),
                          padding: const EdgeInsets.only(left: 8),
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _registrarMovimientoDialog(context),
        backgroundColor: AppTheme.primary,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nuevo Movimiento',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _editarMovimientoDialog(
      BuildContext context, RegistroCaja mov) async {
    final conceptoCtrl = TextEditingController(text: mov.concepto);
    final montoCtrl = TextEditingController(text: mov.monto.toString());
    String tipoSeleccionado = mov.tipo;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Editar Movimiento'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_downward_rounded,
                                  size: 16, color: AppTheme.success),
                              SizedBox(width: 4),
                              Text('Ingreso'),
                            ],
                          ),
                          selected: tipoSeleccionado == 'ingreso',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(
                                  () => tipoSeleccionado = 'ingreso');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_upward_rounded,
                                  size: 16, color: AppTheme.error),
                              SizedBox(width: 4),
                              Text('Egreso'),
                            ],
                          ),
                          selected: tipoSeleccionado == 'egreso',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => tipoSeleccionado = 'egreso');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: conceptoCtrl,
                    decoration: const InputDecoration(labelText: 'Concepto'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: montoCtrl,
                    decoration: const InputDecoration(labelText: 'Monto (\$)'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar',
                    style: TextStyle(color: AppTheme.textTertiary)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final monto = double.tryParse(montoCtrl.text.trim());
                  final concepto = conceptoCtrl.text.trim();
                  if (monto == null || monto <= 0 || concepto.isEmpty) return;

                  Navigator.pop(context);
                  final provider = context.read<OrdenesProvider>();
                  await provider.editarRegistroCaja(
                      mov.id, monto, concepto, tipoSeleccionado);
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> _registrarMovimientoDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final conceptoCtrl = TextEditingController();
    final montoCtrl = TextEditingController();
    String tipoSeleccionado = 'ingreso';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Registrar Movimiento de Caja'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selector de tipo
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_downward_rounded,
                                  size: 16, color: AppTheme.success),
                              SizedBox(width: 4),
                              Text('Ingreso'),
                            ],
                          ),
                          selected: tipoSeleccionado == 'ingreso',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(
                                  () => tipoSeleccionado = 'ingreso');
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.arrow_upward_rounded,
                                  size: 16, color: AppTheme.error),
                              SizedBox(width: 4),
                              Text('Egreso'),
                            ],
                          ),
                          selected: tipoSeleccionado == 'egreso',
                          onSelected: (selected) {
                            if (selected) {
                              setDialogState(() => tipoSeleccionado = 'egreso');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Concepto
                  TextFormField(
                    controller: conceptoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Concepto',
                      hintText: 'Ej. Compra de herramientas, Reparación...',
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (val) => val == null || val.trim().isEmpty
                        ? 'Ingrese un concepto'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  // Monto
                  TextFormField(
                    controller: montoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Monto (\$)',
                      prefixIcon: Icon(Icons.attach_money_rounded),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'))
                    ],
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Ingrese el monto';
                      final numVal = double.tryParse(val);
                      if (numVal == null || numVal <= 0) {
                        return 'Monto inválido';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar',
                    style: TextStyle(color: AppTheme.textTertiary)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;

                  final monto = double.parse(montoCtrl.text.trim());
                  final concepto = conceptoCtrl.text.trim();
                  final provider = context.read<OrdenesProvider>();
                  final messenger = ScaffoldMessenger.of(context);

                  Navigator.pop(context);
                  await provider.registrarMovimientoManual(
                      monto, concepto, tipoSeleccionado);

                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(tipoSeleccionado == 'ingreso'
                          ? 'Ingreso registrado en caja'
                          : 'Egreso registrado en caja'),
                      backgroundColor: tipoSeleccionado == 'ingreso'
                          ? AppTheme.success
                          : AppTheme.error,
                    ),
                  );
                },
                child: const Text('Guardar'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _buildMetricCard({
    required String titulo,
    required String monto,
    required Color color,
    required IconData icon,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tres tarjetas en una fila dejan poco más de 90 px cada una en un
          // teléfono pequeño: «Costos/Gastos» no cabe junto a su icono.
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            monto,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNetProfitCard({
    required String monto,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Ganancia Neta',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Icon(Icons.wallet_rounded, color: Colors.white, size: 16),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            monto,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
