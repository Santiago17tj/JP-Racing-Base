import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../data/models/orden_mantenimiento.dart';
import '../../data/models/cliente.dart';
import '../../data/models/vehiculo.dart';
import '../../data/models/orden_item.dart';
import '../../data/models/repuesto.dart';
import '../../data/providers/ordenes_provider.dart';
import '../../data/providers/inventario_provider.dart';
import '../../core/services/factura_service.dart';
import '../../core/services/pdf_factura_service.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pantalla de detalle técnico y gestión de ítems para una orden de mantenimiento.
class DetalleOrdenScreen extends StatefulWidget {
  final OrdenMantenimiento orden;
  final Cliente cliente;
  final Vehiculo vehiculo;

  const DetalleOrdenScreen({
    super.key,
    required this.orden,
    required this.cliente,
    required this.vehiculo,
  });

  @override
  State<DetalleOrdenScreen> createState() => _DetalleOrdenScreenState();
}

class _DetalleOrdenScreenState extends State<DetalleOrdenScreen> {
  late OrdenMantenimiento _ordenActual;
  List<OrdenItem> _items = [];
  bool _cargandoItems = true;

  // Controladores para diagnóstico y notas
  final _diagnosticoCtrl = TextEditingController();
  final _notasCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ordenActual = widget.orden;
    _diagnosticoCtrl.text = widget.orden.diagnostico ?? '';
    _notasCtrl.text =
        widget.orden.notesMecanico ?? widget.orden.notasMecanico ?? '';
    _cargarItems();
  }

  @override
  void dispose() {
    _diagnosticoCtrl.dispose();
    _notasCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarItems() async {
    setState(() => _cargandoItems = true);
    final provider = context.read<OrdenesProvider>();
    final items = await provider.obtenerItemsOrden(_ordenActual.id);
    // Recargar datos actualizados de la orden en la BD
    final ordenDb = await provider
        .obtenerVehiculoDeOrden(_ordenActual.vehiculoId)
        .then((_) => provider.obtenerClienteDeOrden(_ordenActual.clienteId))
        .then((_) => provider.ordenesActivas.firstWhere(
            (o) => o.id == _ordenActual.id,
            orElse: () => _ordenActual));
    setState(() {
      _items = items;
      _ordenActual = ordenDb;
      _cargandoItems = false;
    });
  }

  Future<void> _guardarNotasMecanico() async {
    final provider = context.read<OrdenesProvider>();
    HapticFeedback.lightImpact();
    await provider.actualizarNotasMecanico(
      ordenId: _ordenActual.id,
      diagnostico: _diagnosticoCtrl.text.trim(),
      notasMecanico: _notasCtrl.text.trim(),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notas del mecánico actualizadas')),
    );
    _cargarItems();
  }

  Future<void> _cambiarEstado(EstadoOrden? nuevoEstado) async {
    if (nuevoEstado == null) return;
    final provider = context.read<OrdenesProvider>();
    HapticFeedback.mediumImpact();
    await provider.cambiarEstadoOrden(_ordenActual.id, nuevoEstado);
    _cargarItems();
  }

  /// Diálogo para agregar concepto de mano de obra
  Future<void> _dialogoManoObra() async {
    final conceptoCtrl = TextEditingController();
    final precioCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar Mano de Obra'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: conceptoCtrl,
                decoration: const InputDecoration(
                    labelText: 'Concepto / Trabajo Realizado'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Precio (\$)',
                  prefixIcon: Icon(Icons.attach_money),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppTheme.textTertiary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final concepto = conceptoCtrl.text.trim();
                final precio = double.tryParse(precioCtrl.text) ?? 0.0;
                if (concepto.isEmpty || precio <= 0) return;

                Navigator.pop(context);
                final provider = context.read<OrdenesProvider>();
                await provider.agregarManoObra(
                    _ordenActual.id, precio, concepto);
                _cargarItems();
              },
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  /// Abre un selector para buscar repuestos e incorporarlos a la orden.
  Future<void> _dialogoAgregarRepuesto() async {
    final provider = context.read<OrdenesProvider>();
    final inventarioProvider = context.read<InventarioProvider>();
    // Garantizar que cargue el inventario actualizado
    await inventarioProvider.cargarRepuestos();

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.background,
      builder: (context) {
        return _SelectorRepuestosModal(
          inventarioProvider: inventarioProvider,
          onRepuestoSelected: (repuesto, cantidad) async {
            final exito = await provider.agregarRepuestoAOrden(
              ordenId: _ordenActual.id,
              repuesto: repuesto,
              cantidad: cantidad,
            );
            if (exito) {
              // Sincronizar stock en el provider del inventario para la UI
              await inventarioProvider.cargarRepuestos();
              _cargarItems();
            }
            return exito;
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Verificar si el estado es LISTA_PARA_ENTREGA para el botón de facturación
    final esListo = _ordenActual.estado == EstadoOrden.listaParaEntrega;

    return Scaffold(
      appBar: AppBar(
        title: Text(_ordenActual.numeroOrden),
        actions: [
          // Selector de Estado de la Orden
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<EstadoOrden>(
              value: _ordenActual.estado,
              dropdownColor: AppTheme.surface,
              underline: const SizedBox(),
              icon: const Icon(Icons.arrow_drop_down,
                  color: AppTheme.primaryLight),
              items: EstadoOrden.values.map((estado) {
                return DropdownMenuItem(
                  value: estado,
                  child: Text(
                    estado.label,
                    style: TextStyle(
                      color: Color(estado.colorValue),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                );
              }).toList(),
              onChanged: _cambiarEstado,
            ),
          ),
        ],
      ),
      body: _cargandoItems
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              children: [
                // ── SECCIÓN 1: CABECERA Y DATOS GENERALES ──
                _buildHeaderCard(),
                const SizedBox(height: AppTheme.spacingMd),

                // ── SECCIÓN 2: DIAGNÓSTICO Y NOTAS DEL MECÁNICO ──
                _buildNotasMecanicoCard(),
                const SizedBox(height: AppTheme.spacingMd),

                // ── SECCIÓN 3: ÍTEMS USADOS Y SERVICIOS ──
                _buildItemsListCard(),
                const SizedBox(height: AppTheme.spacingMd),

                // ── SECCIÓN 4: RESUMEN DE TOTALES Y FACTURACIÓN ──
                _buildTotalesCard(esListo),
                const SizedBox(height: AppTheme.spacingXl),
              ],
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.vehiculo.marca} ${widget.vehiculo.modelo}',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(
                  widget.vehiculo.placaPatente,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            'Cliente: ${widget.cliente.nombreCompleto}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          Text(
            'Contacto: ${widget.cliente.telefono}',
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 12),
          ),
          const Divider(color: AppTheme.surfaceBorder, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMinicell(
                  'KILOMETRAJE ING.', '${_ordenActual.kilometrajeIngreso} km'),
              _buildMinicell('TIPO SERVICIO', _ordenActual.tipoServicio.label),
              _buildMinicell(
                  'MECÁNICO', _ordenActual.mecanicoAsignado ?? 'Sin asignar'),
            ],
          ),
          if (_ordenActual.descripcionProblema != null) ...[
            const Divider(color: AppTheme.surfaceBorder, height: 16),
            const Text(
              'MOTIVO DE INGRESO:',
              style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 4),
            Text(
              _ordenActual.descripcionProblema!,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.3),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildMinicell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
              color: AppTheme.textTertiary,
              fontSize: 8,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildNotasMecanicoCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.assignment_ind_rounded,
                  size: 16, color: AppTheme.primaryLight),
              SizedBox(width: 8),
              Text(
                'DIAGNÓSTICO Y NOTAS TÉCNICAS',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacingMd),
          TextFormField(
            controller: _diagnosticoCtrl,
            decoration: const InputDecoration(
              labelText: 'Diagnóstico Técnico',
              hintText: 'Describe el estado general y repuestos requeridos...',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _notasCtrl,
            decoration: const InputDecoration(
              labelText: 'Notas del Mecánico',
              hintText: 'Tareas realizadas o comentarios internos...',
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _guardarNotasMecanico,
              icon:
                  const Icon(Icons.save_rounded, size: 16, color: Colors.white),
              label: const Text('GUARDAR NOTAS',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceLight,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildItemsListCard() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'REPUESTOS Y TRABAJOS',
                style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.build_rounded,
                        size: 18, color: AppTheme.primaryLight),
                    tooltip: 'Mano de Obra',
                    onPressed: _dialogoManoObra,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_shopping_cart_rounded,
                        size: 18, color: AppTheme.success),
                    tooltip: 'Agregar Repuesto',
                    onPressed: _dialogoAgregarRepuesto,
                  ),
                ],
              )
            ],
          ),
          const Divider(color: AppTheme.surfaceBorder, height: 16),
          if (_items.isEmpty && _ordenActual.costoManoObra == 0.0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No se han agregado repuestos ni mano de obra.',
                  style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                ),
              ),
            )
          else ...[
            // Mano de obra agregada
            if (_ordenActual.costoManoObra > 0) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚙️ Mano de Obra Acumulada',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Trabajos mecánicos registrados',
                        style: TextStyle(
                            color: AppTheme.textTertiary, fontSize: 11),
                      ),
                    ],
                  ),
                  Text(
                    '\$${_ordenActual.costoManoObra.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(color: AppTheme.surfaceBorder, height: 16),
            ],

            // Repuestos
            ..._items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.descripcion,
                            style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Cantidad: ${item.cantidad} x \$${item.precioUnitario.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: AppTheme.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '\$${item.subtotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            }),
          ]
        ],
      ),
    );
  }

  Widget _buildTotalesCard(bool esListo) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal Repuestos',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              Text('\$${_ordenActual.subtotalRepuestos.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Subtotal Mano de Obra',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              Text('\$${_ordenActual.costoManoObra.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13)),
            ],
          ),
          const Divider(color: AppTheme.surfaceBorder, height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL ESTIMADO',
                style: TextStyle(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.bold,
                    fontSize: 14),
              ),
              Text(
                '\$${_ordenActual.totalEstimado.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.w900,
                    fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Botón Prominente de Factura
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: esListo
                  ? () {
                      HapticFeedback.mediumImpact();
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: AppTheme.background,
                        builder: (context) => _FacturaPreviewSheet(
                          orden: _ordenActual,
                          cliente: widget.cliente,
                          vehiculo: widget.vehiculo,
                          items: _items,
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
              label: const Text(
                'GENERAR FACTURA INVOICE FLY',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 0.5),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                disabledBackgroundColor: AppTheme.surfaceLight,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              ),
            ),
          ),
          if (!esListo) ...[
            const SizedBox(height: 8),
            const Text(
              'Nota: Cambie el estado de la orden a "Lista para Entrega" en el selector superior para habilitar la facturación rápida.',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ]
        ],
      ),
    );
  }
}

class _FacturaPreviewSheet extends StatelessWidget {
  final OrdenMantenimiento orden;
  final Cliente cliente;
  final Vehiculo vehiculo;
  final List<OrdenItem> items;

  const _FacturaPreviewSheet({
    required this.orden,
    required this.cliente,
    required this.vehiculo,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final subtotalRepuestos =
        items.fold<double>(0.0, (sum, item) => sum + item.subtotal);
    final total = orden.costoManoObra + subtotalRepuestos;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                children: [
                  const Icon(Icons.receipt_long_rounded,
                      color: AppTheme.primaryLight),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Factura de servicio',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF121826), Color(0xFF1B2335)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.surfaceBorder, width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primarySurface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'Imagenes/ChatGPT Image 24 jun 2026, 01_34_18 p.m..png',
                              width: 64,
                              height: 64,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MOTO TALLER',
                                  style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryLight)),
                              const SizedBox(height: 4),
                              Text('Servicio técnico y repuestos',
                                  style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 13)),
                              const SizedBox(height: 6),
                              Text('Factura de servicio',
                                  style: TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(orden.estado.label,
                              style: const TextStyle(
                                  color: AppTheme.primaryLight,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingLg),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _buildFacturaMeta('ORDEN', orden.numeroOrden),
                        _buildFacturaMeta('FECHA', DateTime.now().toLocal().toString().split('.')[0]),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cliente: ${cliente.nombreCompleto}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Vehículo: ${vehiculo.marca} ${vehiculo.modelo} - ${vehiculo.placaPatente}', style: TextStyle(color: AppTheme.textSecondary)),
                          Text('Kilometraje: ${orden.kilometrajeIngreso} km', style: TextStyle(color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                    const Divider(color: AppTheme.surfaceBorder),
                    ...items.map((item) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceLight.withOpacity(0.55),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Expanded(child: Text(item.descripcion, style: const TextStyle(fontSize: 13))),
                              Text('${item.cantidad} x \$${item.precioUnitario.toStringAsFixed(2)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('Sin items registrados', style: TextStyle(color: AppTheme.textTertiary)),
                      ),
                    const Divider(color: AppTheme.surfaceBorder),
                    _buildFacturaTotalRow('Mano de obra', orden.costoManoObra),
                    const SizedBox(height: 6),
                    _buildFacturaTotalRow('Subtotal repuestos', subtotalRepuestos),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primarySurface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('TOTAL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.primaryLight)),
                          Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryLight)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final body = FacturaService.buildEmailBody(
                        numeroOrden: orden.numeroOrden,
                        cliente: cliente.nombreCompleto,
                        vehiculo: '${vehiculo.marca} ${vehiculo.modelo}',
                        total: total,
                        items: items.map((item) => item.descripcion).toList(),
                      );
                      final mailtoLink = FacturaService.buildMailtoLink(
                        to: 'taller@motoapp.com',
                        subject: 'Factura ${orden.numeroOrden}',
                        body: body,
                      );
                      final uri = Uri.parse(mailtoLink);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Factura enviada por correo')),
                        );
                      }
                    },
                    icon: const Icon(Icons.email_rounded),
                    label: const Text('Enviar por correo'),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        final path = await PdfFacturaService.generarFacturaPdf(
                          orden: orden,
                          cliente: cliente,
                          vehiculo: vehiculo,
                          items: items,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Se preparó el PDF para descargar')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('No se pudo generar el PDF: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Descargar PDF'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFacturaMeta(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildFacturaTotalRow(String label, double value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary)),
        Text('\$${value.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Selector modal para buscar y añadir repuestos a la orden de servicio.
class _SelectorRepuestosModal extends StatefulWidget {
  final InventarioProvider inventarioProvider;
  final Future<bool> Function(Repuesto repuesto, int cantidad)
      onRepuestoSelected;

  const _SelectorRepuestosModal({
    required this.inventarioProvider,
    required this.onRepuestoSelected,
  });

  @override
  State<_SelectorRepuestosModal> createState() =>
      _SelectorRepuestosModalState();
}

class _SelectorRepuestosModalState extends State<_SelectorRepuestosModal> {
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
                                    'SKU: ${rep.codigoInterno}  |  Stock: ${rep.stockActual}  |  Precio: \$${rep.precioVenta.toStringAsFixed(2)}',
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
                                        setState(() => _procesando = true);
                                        HapticFeedback.lightImpact();
                                        final exito =
                                            await widget.onRepuestoSelected(
                                                rep, cantActual);
                                        setState(() => _procesando = false);

                                        if (exito && mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                                content: Text(
                                                    'Añadido: ${rep.nombre}')),
                                          );
                                        } else if (mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
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
