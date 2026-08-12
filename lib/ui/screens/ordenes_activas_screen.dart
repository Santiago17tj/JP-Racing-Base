import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../data/models/orden_mantenimiento.dart';
import '../../data/models/cliente.dart';
import '../../data/models/vehiculo.dart';
import '../../data/providers/ordenes_provider.dart';
import 'crear_orden_screen.dart';
import 'detalle_orden_screen.dart';

import 'venta_rapida_screen.dart';

/// Pantalla Principal de Órdenes Activas del taller.
///
/// Organiza las órdenes en pestañas deslizables (Tabbar) por su estado de flujo.
class OrdenesActivasScreen extends StatefulWidget {
  const OrdenesActivasScreen({super.key});

  @override
  State<OrdenesActivasScreen> createState() => _OrdenesActivasScreenState();
}

class _OrdenesActivasScreenState extends State<OrdenesActivasScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _busquedaCtrl = TextEditingController();
  String _busqueda = '';

  final List<EstadoOrden> _estadosTab = [
    EstadoOrden.ingresada,
    EstadoOrden.enDiagnostico,
    EstadoOrden.enReparacion,
    EstadoOrden.listaParaEntrega,
  ];

  @override
  void initState() {
    super.initState();
    // Una pestaña por estado activo + la de historial (entregadas/canceladas).
    _tabController = TabController(length: _estadosTab.length + 1, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdenesProvider>().cargarDatos();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _busquedaCtrl.dispose();
    super.dispose();
  }

  /// Filtra por número de orden, placa, marca/modelo o nombre del cliente.
  List<OrdenMantenimiento> _filtrar(
      List<OrdenMantenimiento> ordenes, OrdenesProvider provider) {
    final q = _busqueda.trim().toLowerCase();
    if (q.isEmpty) return ordenes;

    return ordenes.where((o) {
      final cliente = provider.clienteDe(o.clienteId);
      final vehiculo = provider.vehiculoDe(o.vehiculoId);
      final texto = [
        o.numeroOrden,
        cliente?.nombreCompleto ?? '',
        vehiculo?.placaPatente ?? '',
        vehiculo?.marca ?? '',
        vehiculo?.modelo ?? '',
      ].join(' ').toLowerCase();
      return texto.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdenesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taller & Servicios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_rounded,
                color: AppTheme.primaryLight),
            tooltip: 'Venta Rápida de Mostrador',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const VentaRapidaScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primaryLight,
          unselectedLabelColor: AppTheme.textTertiary,
          tabs: [
            ..._estadosTab.map((estado) {
              final count = provider.getOrdenesPorEstado(estado).length;
              return Tab(
                child: Row(
                  children: [
                    Text(estado.label),
                    if (count > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: AppTheme.gradientForEstado(
                                estado.value.toLowerCase()),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
            Tab(
              child: Row(
                children: [
                  const Text('Historial'),
                  if (provider.historial.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${provider.historial.length}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildBuscador(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ..._estadosTab.map((estado) {
                        final ordenes = _filtrar(
                            provider.getOrdenesPorEstado(estado), provider);
                        return _buildOrdenesList(ordenes, estado);
                      }),
                      _buildOrdenesList(
                        _filtrar(provider.historial, provider),
                        EstadoOrden.entregada,
                        esHistorial: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CrearOrdenScreen()),
          );
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Nueva Orden',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  /// Buscador por placa, cliente o número de orden.
  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppTheme.spacingMd, AppTheme.spacingSm, AppTheme.spacingMd, 0),
      child: TextField(
        controller: _busquedaCtrl,
        onChanged: (v) => setState(() => _busqueda = v),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Buscar por placa, cliente u orden...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          isDense: true,
          suffixIcon: _busqueda.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: 'Limpiar búsqueda',
                  onPressed: () {
                    _busquedaCtrl.clear();
                    setState(() => _busqueda = '');
                    FocusScope.of(context).unfocus();
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildOrdenesList(
      List<OrdenMantenimiento> ordenes, EstadoOrden estado,
      {bool esHistorial = false}) {
    if (ordenes.isEmpty && _busqueda.trim().isNotEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacingLg),
          child: Text(
            'Ninguna orden coincide con la búsqueda.',
            style: TextStyle(color: AppTheme.textTertiary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (ordenes.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getIconForEstado(estado),
                size: 48,
                color: AppTheme.textTertiary,
              ),
              const SizedBox(height: AppTheme.spacingMd),
              Text(
                estado == EstadoOrden.entregada
                    ? 'Historial vacío'
                    : 'Sin motos en ${estado.label}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXs),
              Text(
                estado == EstadoOrden.entregada
                    ? 'Aquí aparecerán las órdenes entregadas para consultar trabajos anteriores y reimprimir facturas.'
                    : 'No hay ninguna orden activa registrada en este estado en este momento.',
                style:
                    const TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // El historial se trae por páginas: al final de la lista aparece el botón
    // para pedir el siguiente bloque.
    final provider = context.watch<OrdenesProvider>();
    final mostrarCargarMas = esHistorial &&
        provider.hayMasHistorial &&
        _busqueda.trim().isEmpty;

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: ordenes.length + (mostrarCargarMas ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == ordenes.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
            child: Center(
              child: provider.cargandoHistorial
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : OutlinedButton.icon(
                      onPressed: provider.cargarMasHistorial,
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: const Text('Cargar órdenes anteriores'),
                    ),
            ),
          );
        }
        return _OrdenCard(orden: ordenes[index]);
      },
    );
  }

  IconData _getIconForEstado(EstadoOrden estado) {
    switch (estado) {
      case EstadoOrden.ingresada:
        return Icons.login_rounded;
      case EstadoOrden.enDiagnostico:
        return Icons.search_rounded;
      case EstadoOrden.enReparacion:
        return Icons.build_circle_outlined;
      case EstadoOrden.listaParaEntrega:
        return Icons.check_circle_outline_rounded;
      case EstadoOrden.entregada:
        return Icons.done_all_rounded;
      case EstadoOrden.cancelada:
        return Icons.cancel_outlined;
    }
  }
}

/// Tarjeta visual para representar la Orden de Mantenimiento en la lista.
class _OrdenCard extends StatelessWidget {
  final OrdenMantenimiento orden;

  const _OrdenCard({required this.orden});

  @override
  Widget build(BuildContext context) {
    // El cliente y la moto salen del índice en memoria del provider: antes se
    // consultaba la base de datos dos veces por tarjeta en cada repintado.
    final provider = context.watch<OrdenesProvider>();
    final cliente = provider.clienteDe(orden.clienteId);
    final vehiculo = provider.vehiculoDe(orden.vehiculoId);

    if (cliente == null || vehiculo == null) {
      // Respaldo para un registro que aún no esté en el índice.
      return FutureBuilder<List<dynamic>>(
        future: Future.wait([
          provider.obtenerClienteDeOrden(orden.clienteId),
          provider.obtenerVehiculoDeOrden(orden.vehiculoId),
        ]),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Container(
              height: 100,
              margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
              decoration: AppTheme.cardDecoration,
              child: const Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            );
          }
          final c = snapshot.data![0] as Cliente?;
          final v = snapshot.data![1] as Vehiculo?;
          if (c == null || v == null) return const SizedBox.shrink();
          return _buildTarjeta(context, c, v);
        },
      );
    }

    return _buildTarjeta(context, cliente, vehiculo);
  }

  Widget _buildTarjeta(
      BuildContext context, Cliente cliente, Vehiculo vehiculo) {
    {
      // Determinar color de alerta de tiempo en el taller
      // Si lleva más de 3 días en el taller, advertencia
      final dias = orden.diasEnTaller;
      Color diasColor = AppTheme.textTertiary;
      if (dias >= 5) {
        diasColor = AppTheme.error;
      } else if (dias >= 3) {
        diasColor = AppTheme.warning;
      }

      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DetalleOrdenScreen(
                orden: orden,
                cliente: cliente,
                vehiculo: vehiculo,
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
          decoration: AppTheme.cardDecoration,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera: Consecutivo + Días
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      orden.numeroOrden,
                      style: const TextStyle(
                        color: AppTheme.primaryLight,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            color: diasColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          dias == 0
                              ? 'Ingresó hoy'
                              : 'Hace $dias ${dias == 1 ? 'día' : 'días'}',
                          style: TextStyle(
                            color: diasColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacingSm),

                // Info de la Moto (Marca y Modelo)
                Text(
                  '${vehiculo.marca} ${vehiculo.modelo}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                // Placa y Cliente
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.surfaceBorder),
                      ),
                      child: Text(
                        vehiculo.placaPatente,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Dueño: ${cliente.nombreCompleto}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const Divider(color: AppTheme.surfaceBorder, height: 24),

                // Fila inferior: Mecánico y Tipo de Servicio
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.engineering_rounded,
                            color: AppTheme.textTertiary, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          orden.mecanicoAsignado ?? 'Sin asignar',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceLight,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppTheme.surfaceBorder),
                            ),
                            child: Text(
                              orden.tipoServicio,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: AppTheme.gradientForEstado(
                                    orden.estado.value.toLowerCase()),
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.gradientForEstado(
                                          orden.estado.value.toLowerCase())
                                      .first
                                      .withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              orden.estado.label.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      );
    }
  }
}
