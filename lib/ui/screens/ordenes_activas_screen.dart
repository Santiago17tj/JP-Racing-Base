import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../data/models/orden_mantenimiento.dart';
import '../../data/models/cliente.dart';
import '../../data/models/vehiculo.dart';
import '../../data/providers/ordenes_provider.dart';
import 'crear_orden_screen.dart';
import 'detalle_orden_screen.dart';

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

  final List<EstadoOrden> _estadosTab = [
    EstadoOrden.ingresada,
    EstadoOrden.enDiagnostico,
    EstadoOrden.enReparacion,
    EstadoOrden.listaParaEntrega,
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _estadosTab.length, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrdenesProvider>().cargarDatos();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdenesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Taller & Servicios'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppTheme.primary,
          labelColor: AppTheme.primaryLight,
          unselectedLabelColor: AppTheme.textTertiary,
          tabs: _estadosTab.map((estado) {
            final count = provider.getOrdenesPorEstado(estado).length;
            return Tab(
              child: Row(
                children: [
                  Text(estado.label),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Color(estado.colorValue).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: Color(estado.colorValue),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _estadosTab.map((estado) {
                final ordenes = provider.getOrdenesPorEstado(estado);
                return _buildOrdenesList(ordenes, estado);
              }).toList(),
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

  Widget _buildOrdenesList(List<OrdenMantenimiento> ordenes, EstadoOrden estado) {
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
                'Sin motos en ${estado.label}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppTheme.spacingXs),
              const Text(
                'No hay ninguna orden activa registrada en este estado en este momento.',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      itemCount: ordenes.length,
      itemBuilder: (context, index) {
        final orden = ordenes[index];
        return _OrdenCard(orden: orden);
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
    final provider = context.read<OrdenesProvider>();

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
            child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
          );
        }

        final cliente = snapshot.data![0] as Cliente?;
        final vehiculo = snapshot.data![1] as Vehiculo?;

        if (cliente == null || vehiculo == null) {
          return const SizedBox.shrink();
        }

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
                          Icon(Icons.access_time_rounded, color: diasColor, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            dias == 0 ? 'Ingresó hoy' : 'Hace $dias ${dias == 1 ? 'día' : 'días'}',
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          const Icon(Icons.engineering_rounded, color: AppTheme.textTertiary, size: 14),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          orden.tipoServicio.label,
                          style: const TextStyle(
                            color: AppTheme.primaryLight,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
