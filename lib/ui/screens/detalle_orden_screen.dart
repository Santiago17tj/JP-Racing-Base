import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/checklist_diagnostico_sheet.dart';
import '../widgets/factura_preview_sheet.dart';
import '../widgets/selector_repuestos_modal.dart';
import 'editar_orden_screen.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../data/models/orden_mantenimiento.dart';
import '../../data/models/cliente.dart';
import '../../data/models/vehiculo.dart';
import '../../data/models/orden_item.dart';
import '../../data/models/abono.dart';
import '../../data/providers/ordenes_provider.dart';
import '../../data/providers/inventario_provider.dart';
import '../../data/providers/taller_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../core/dominio/reglas_orden.dart';
import '../../core/services/factus_service.dart';
import '../../core/config/app_config.dart';
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notas del mecánico actualizadas')),
    );
    _cargarItems();
  }

  /// Abre WhatsApp con un mensaje ya redactado sobre el estado de la moto.
  Future<void> _escribirPorWhatsapp() async {
    final telefono = widget.cliente.telefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (telefono.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('El cliente no tiene un teléfono registrado.')),
      );
      return;
    }

    // Si no trae indicativo, se asume Colombia (57).
    final numero = telefono.length <= 10 ? '57$telefono' : telefono;

    final taller = context.read<TallerProvider>().taller;
    final nombreTaller = (taller?.nombreTaller ?? '').trim().isNotEmpty
        ? taller!.nombreTaller
        : 'el taller';
    final saldo = _ordenActual
        .saldoPendienteConImpuesto(taller?.porcentajeImpuestoDefecto ?? 0.0);

    final mensaje = StringBuffer()
      ..write('Hola ${widget.cliente.nombre}, le escribimos de $nombreTaller ')
      ..write('sobre su ${widget.vehiculo.marca} ${widget.vehiculo.modelo} ')
      ..write('(placa ${widget.vehiculo.placaPatente}), ')
      ..write('orden ${_ordenActual.numeroOrden}. ')
      ..write('Estado actual: ${_ordenActual.estado.label}.');
    if (saldo > 0) {
      mensaje.write(' Saldo pendiente: ${CurrencyFormatter.format(saldo)}.');
    }

    final url = Uri.parse(
        'https://wa.me/$numero?text=${Uri.encodeComponent(mensaje.toString())}');

    try {
      final abierto =
          await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!abierto && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir WhatsApp: $e')),
        );
      }
    }
  }

  /// Abre la hoja de inspección "¿Qué tiene la moto?" y vuelca el resultado
  /// en el campo de diagnóstico técnico.
  Future<void> _abrirChecklistDiagnostico() async {
    HapticFeedback.selectionClick();
    final resultado = await ChecklistDiagnosticoSheet.mostrar(
      context,
      _diagnosticoCtrl.text,
    );
    if (resultado == null || !mounted) return;
    setState(() => _diagnosticoCtrl.text = resultado);
    await _guardarNotasMecanico();
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
                    _ordenActual.id, precio, 'Mano de obra: $concepto');
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
        return SelectorRepuestosModal(
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
    // La factura se habilita cuando la moto está lista y sigue disponible
    // después de entregada, para poder reimprimirla desde el historial.
    final esListo = _ordenActual.estado == EstadoOrden.listaParaEntrega ||
        _ordenActual.estado == EstadoOrden.entregada;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taller - Detalle de Orden'),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_rounded, color: AppTheme.success),
            tooltip: 'Escribir al cliente por WhatsApp',
            onPressed: _escribirPorWhatsapp,
          ),
          IconButton(
            icon: const Icon(Icons.edit_document),
            tooltip: 'Editar Orden',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        EditarOrdenScreen(ordenActual: _ordenActual)),
              );
              if (mounted) _cargarItems();
            },
          ),
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
              _buildMinicell('TIPO SERVICIO', _ordenActual.tipoServicio),
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
            readOnly: true,
            onTap: _abrirChecklistDiagnostico,
            minLines: 2,
            maxLines: 8,
            style: const TextStyle(fontSize: 13, height: 1.35),
            decoration: const InputDecoration(
              labelText: 'Diagnóstico Técnico',
              hintText: 'Toca para revisar qué tiene la moto...',
              prefixIcon: Icon(Icons.two_wheeler_rounded,
                  color: AppTheme.primaryLight, size: 20),
              suffixIcon: Icon(Icons.chevron_right_rounded,
                  color: AppTheme.textTertiary),
            ),
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
                  IconButton(
                    icon: const Icon(Icons.add_business_rounded,
                        size: 18, color: AppTheme.warning),
                    tooltip: 'Repuesto Externo',
                    onPressed: _dialogoRepuestoExterno,
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
                    CurrencyFormatter.format(_ordenActual.costoManoObra),
                    style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._items.where(ReglasOrden.esManoObra).map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6.0, left: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '- ${item.descripcion.replaceAll('Mano de obra: ', '')}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(item.precioUnitario),
                        style: const TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => _confirmarEliminarItem(item),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded,
                              size: 16, color: AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(color: AppTheme.surfaceBorder, height: 16),
            ],

            // Repuestos (excluding mano de obra items)
            ..._items.where((i) => !ReglasOrden.esManoObra(i)).map((item) {
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
                            'Cantidad: ${item.cantidad} x ${CurrencyFormatter.format(item.precioUnitario)}',
                            style: const TextStyle(
                                color: AppTheme.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(item.subtotal),
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _confirmarEliminarItem(item),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: AppTheme.error),
                      ),
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

  /// Diálogo de confirmación antes de eliminar un ítem de la orden.
  Future<void> _confirmarEliminarItem(OrdenItem item) async {
    final esManoObra = ReglasOrden.esManoObra(item);
    final descripcion = esManoObra
        ? item.descripcion.replaceAll('Mano de obra: ', '')
        : item.descripcion;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.delete_forever_rounded, color: AppTheme.error),
            SizedBox(width: 8),
            Text('Eliminar Ítem', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Estás seguro de eliminar este ${esManoObra ? "concepto de mano de obra" : "repuesto"} de la orden?',
              style:
                  const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      descripcion,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(
                        esManoObra ? item.precioUnitario : item.subtotal),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.error,
                        fontSize: 12),
                  ),
                ],
              ),
            ),
            if (!esManoObra && item.repuestoId != 'item-externo-generico')
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  '💡 El stock del repuesto será restaurado al inventario.',
                  style: TextStyle(color: AppTheme.success, fontSize: 11),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;
    // La pantalla pudo cerrarse mientras el diálogo estaba abierto.
    if (!mounted) return;

    final provider = context.read<OrdenesProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final exito = await provider.eliminarItemDeOrden(
      itemId: item.id,
      ordenId: _ordenActual.id,
    );

    if (exito) {
      _cargarItems();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Eliminado: $descripcion'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Error al eliminar el ítem')),
      );
    }
  }

  /// Diálogo para agregar un repuesto externo (comprado afuera) con nombre y precio manual.
  Future<void> _dialogoRepuestoExterno() async {
    final nombreCtrl = TextEditingController();
    final precioCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Row(
            children: [
              Icon(Icons.add_business_rounded, color: AppTheme.warning),
              SizedBox(width: 8),
              Flexible(
                child: Text('Repuesto Externo', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Agrega un repuesto que no está en tu inventario (comprado afuera).',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Repuesto',
                  hintText: 'Ej: Cadena 520 RK Racing',
                  prefixIcon: Icon(Icons.label_rounded),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: precioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Precio Unitario (\$)',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cantidadCtrl,
                decoration: const InputDecoration(
                  labelText: 'Cantidad',
                  prefixIcon: Icon(Icons.numbers_rounded),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
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
            ElevatedButton.icon(
              onPressed: () async {
                final nombre = nombreCtrl.text.trim();
                final precio = double.tryParse(precioCtrl.text) ?? 0.0;
                final cantidad = int.tryParse(cantidadCtrl.text) ?? 1;

                if (nombre.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Ingresa un nombre para el repuesto')),
                  );
                  return;
                }
                if (precio <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Ingresa un precio válido mayor a 0')),
                  );
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                final provider = context.read<OrdenesProvider>();
                Navigator.pop(context);
                final exito = await provider.agregarRepuestoExterno(
                  ordenId: _ordenActual.id,
                  nombre: nombre,
                  precio: precio,
                  cantidad: cantidad,
                );
                if (exito) {
                  _cargarItems();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Repuesto externo añadido: $nombre'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  /// Porcentaje de IVA configurado en Ajustes del Taller (0 si no aplica).
  double get _porcentajeImpuesto =>
      context.watch<TallerProvider>().taller?.porcentajeImpuestoDefecto ?? 0.0;

  Widget _buildTotalesCard(bool esListo) {
    final porcentaje = _porcentajeImpuesto;
    final impuesto = _ordenActual.impuestoManoObra(porcentaje);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  porcentaje > 0
                      ? 'Subtotal Repuestos (IVA incl.)'
                      : 'Subtotal Repuestos',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              Text(CurrencyFormatter.format(_ordenActual.subtotalRepuestos),
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
              Text(CurrencyFormatter.format(_ordenActual.costoManoObra),
                  style: const TextStyle(
                      color: AppTheme.textPrimary, fontSize: 13)),
            ],
          ),
          if (impuesto > 0) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('IVA ${porcentaje.toStringAsFixed(1)}% (mano de obra)',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
                Text(CurrencyFormatter.format(impuesto),
                    style: const TextStyle(
                        color: AppTheme.textPrimary, fontSize: 13)),
              ],
            ),
          ],
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
                CurrencyFormatter.format(
                    _ordenActual.totalConImpuesto(porcentaje)),
                style: const TextStyle(
                    color: AppTheme.primaryLight,
                    fontWeight: FontWeight.w900,
                    fontSize: 16),
              ),
            ],
          ),
          _buildEstadoPagoCard(),
          const SizedBox(height: 16),

          // Botón Prominente de Factura
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: esListo
                  ? () {
                      HapticFeedback.mediumImpact();
                      if (AppConfig.facturacionElectronicaActiva) {
                        // El aviso se resuelve cuando la DIAN responde, que
                        // puede ser mucho después: se captura el messenger
                        // ahora, mientras la pantalla existe con seguridad.
                        final messenger = ScaffoldMessenger.of(context);
                        FactusService.emitirFacturaElectronica(
                          orden: _ordenActual,
                          cliente: widget.cliente,
                          vehiculo: widget.vehiculo,
                          items: _items,
                          taller: context.read<TallerProvider>().taller,
                        ).then((res) {
                          if (res['success'] == true) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Factura electrónica emitida DIAN (CUFE: ${res['cufe']})'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                          }
                        });
                      }
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: AppTheme.background,
                        builder: (context) => FacturaPreviewSheet(
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

  Widget _buildEstadoPagoCard() {
    final porcentaje = _porcentajeImpuesto;
    final totalConIva = _ordenActual.totalConImpuesto(porcentaje);
    final saldoConIva = _ordenActual.saldoPendienteConImpuesto(porcentaje);

    // El estado guardado no contempla el IVA; si aún queda saldo con impuesto
    // incluido, la orden no puede mostrarse como pagada.
    final estadoPago = saldoConIva > 0 && _ordenActual.estadoPago == 'pagado'
        ? (_ordenActual.montoPagado > 0 ? 'parcial' : 'pendiente')
        : _ordenActual.estadoPago;
    Color estadoColor;
    String estadoText;

    if (estadoPago == 'pagado') {
      estadoColor = AppTheme.success;
      estadoText = 'PAGADO';
    } else if (estadoPago == 'parcial') {
      estadoColor = AppTheme.warning;
      estadoText = 'PAGO PARCIAL';
    } else {
      estadoColor = AppTheme.error;
      estadoText = 'PENDIENTE DE PAGO';
    }

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: estadoColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ESTADO DE PAGO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: estadoColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  estadoText,
                  style: TextStyle(
                    color: estadoColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child:
                    _buildMontoBox('Total', totalConIva, AppTheme.textPrimary),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMontoBox(
                    'Abonado', _ordenActual.montoPagado, AppTheme.success),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMontoBox('Pendiente', saldoConIva, AppTheme.error),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _mostrarDialogoAbono(),
              icon: const Icon(Icons.payments_rounded, size: 18),
              label: const Text('💵 Registrar Abono / Anticipo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryLight,
                side: const BorderSide(color: AppTheme.primaryLight),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ),
          ),
          FutureBuilder<List<Abono>>(
            future: context
                .read<OrdenesProvider>()
                .obtenerAbonosDeOrden(_ordenActual.id),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              final abonos = snapshot.data!;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  const Divider(color: AppTheme.surfaceBorder, height: 12),
                  const Text('Historial de Abonos:',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                  ...abonos.map((a) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                                '${a.fecha.day}/${a.fecha.month}/${a.fecha.year} (${a.metodoPago.toUpperCase()})',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.textTertiary)),
                            Text('+ ${CurrencyFormatter.format(a.monto)}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.success)),
                          ],
                        ),
                      )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMontoBox(String title, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 9, color: AppTheme.textTertiary)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.format(value),
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoAbono() async {
    final montoCtrl = TextEditingController();
    final notasCtrl = TextEditingController();
    String metodoSeleccionado = 'efectivo';
    final porcentaje =
        context.read<TallerProvider>().taller?.porcentajeImpuestoDefecto ?? 0.0;
    final saldoConIva = _ordenActual.saldoPendienteConImpuesto(porcentaje);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.surface,
          title: const Row(
            children: [
              Icon(Icons.payments_rounded, color: AppTheme.primaryLight),
              SizedBox(width: 8),
              Text('Registrar Abono', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Saldo pendiente: ${CurrencyFormatter.format(saldoConIva)}',
                style: const TextStyle(
                    color: AppTheme.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: montoCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Monto del Abono (\$)',
                  prefixIcon: Icon(Icons.attach_money_rounded),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: metodoSeleccionado,
                dropdownColor: AppTheme.surface,
                decoration: const InputDecoration(labelText: 'Método de Pago'),
                items: const [
                  DropdownMenuItem(value: 'efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(
                      value: 'transferencia',
                      child: Text('Transferencia Bancaria')),
                  DropdownMenuItem(
                      value: 'nequi', child: Text('Nequi / Daviplata')),
                  DropdownMenuItem(
                      value: 'tarjeta', child: Text('Tarjeta Débito/Crédito')),
                ],
                onChanged: (v) {
                  if (v != null) setDialogState(() => metodoSeleccionado = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notasCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notas / Referencia (Opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar',
                  style: TextStyle(color: AppTheme.textTertiary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final monto = double.tryParse(montoCtrl.text.trim());
                if (monto == null || monto <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Ingrese un monto válido mayor a 0')),
                  );
                  return;
                }
                Navigator.pop(ctx);

                try {
                  final provider = context.read<OrdenesProvider>();
                  await provider.registrarAbono(
                    ordenId: _ordenActual.id,
                    monto: monto,
                    metodoPago: metodoSeleccionado,
                    porcentajeImpuesto: porcentaje,
                    notas: notasCtrl.text.trim().isEmpty
                        ? null
                        : notasCtrl.text.trim(),
                  );

                  final ordenes = provider.ordenesActivas;
                  final idx =
                      ordenes.indexWhere((o) => o.id == _ordenActual.id);
                  if (idx != -1) {
                    setState(() {
                      _ordenActual = ordenes[idx];
                    });
                  }

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            'Abono de ${CurrencyFormatter.format(monto)} registrado con éxito.'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error registrando abono: $e')),
                    );
                  }
                }
              },
              style:
                  ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
              child: const Text('Guardar Abono'),
            ),
          ],
        ),
      ),
    );
  }
}
