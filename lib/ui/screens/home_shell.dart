import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/taller_provider.dart';
import 'ordenes_activas_screen.dart';
import 'inventario_screen.dart';
import 'cloud_inventory_screen.dart';
import 'ajustes_taller_screen.dart';
import '../widgets/aviso_sincronizacion.dart';

/// Contenedor principal de la aplicación con navegación inferior.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const OrdenesActivasScreen(),
    const InventarioScreen(),
    const CloudInventoryScreen(),
    const AjustesTallerScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final tallerProvider = Provider.of<TallerProvider>(context, listen: false);
      if (tallerProvider.taller == null) {
        await tallerProvider.cargarTaller(auth.currentUserId ?? 'demo-user');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TallerProvider>(
      builder: (context, tallerProvider, _) {
        // v1.1.5: Bloqueo estricto del Dashboard hasta que el perfil del taller
        // se haya descargado completamente desde Supabase y guardado en SQLite.
        // Evita que la app entre al Dashboard con datos vacíos o incorrectos.
        if (tallerProvider.isLoading || tallerProvider.taller == null) {
          return const Scaffold(
            backgroundColor: AppTheme.background,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppTheme.primaryLight),
                  SizedBox(height: 24),
                  Text(
                    'Cargando perfil del taller...',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          body: Column(
            children: [
              // Franja de «N cambios sin subir». Se oculta sola cuando no hay
              // nada pendiente; sin ella, un fallo de sincronización vuelve a
              // ser invisible.
              const SafeArea(bottom: false, child: AvisoSincronizacion()),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _screens,
                ),
              ),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            backgroundColor: AppTheme.surface,
            selectedItemColor: AppTheme.primaryLight,
            unselectedItemColor: AppTheme.textTertiary,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.build_circle_outlined),
                activeIcon: Icon(Icons.build_circle_rounded),
                label: 'Servicios',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.inventory_2_outlined),
                activeIcon: Icon(Icons.inventory_2_rounded),
                label: 'Inventario',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.cloud_done_outlined),
                activeIcon: Icon(Icons.cloud_done_rounded),
                label: 'Cloud',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings_rounded),
                label: 'Ajustes',
              ),
            ],
          ),
        );
      },
    );
  }
}
