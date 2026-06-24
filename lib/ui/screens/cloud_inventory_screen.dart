import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/repuesto.dart';
import '../../data/providers/inventario_provider.dart';
import 'agregar_repuesto_screen.dart';

class CloudInventoryScreen extends StatefulWidget {
  const CloudInventoryScreen({super.key});

  @override
  State<CloudInventoryScreen> createState() => _CloudInventoryScreenState();
}

class _CloudInventoryScreenState extends State<CloudInventoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InventarioProvider>().cargarRepuestos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InventarioProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventario Cloud'),
        actions: [
          IconButton(onPressed: () => provider.cargarRepuestos(), icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AgregarRepuestoScreen())),
        icon: const Icon(Icons.add_photo_alternate_rounded),
        label: const Text('Nuevo repuesto'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.repuestos.length,
              itemBuilder: (context, index) {
                final repuesto = provider.repuestos[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: AppTheme.primarySurface,
                        backgroundImage: repuesto.fotoUrl != null && repuesto.fotoUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(repuesto.fotoUrl!)
                            : null,
                        child: repuesto.fotoUrl == null || repuesto.fotoUrl!.isEmpty
                            ? const Icon(Icons.inventory_2_rounded, color: AppTheme.primaryLight)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(repuesto.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('Stock: ${repuesto.stockActual}', style: const TextStyle(color: AppTheme.textSecondary)),
                            Text('Precio: \$${repuesto.precioVenta.toStringAsFixed(2)}', style: const TextStyle(color: AppTheme.textTertiary)),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => provider.eliminarRepuesto(repuesto.id),
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
