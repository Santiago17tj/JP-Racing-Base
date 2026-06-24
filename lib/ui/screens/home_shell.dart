import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import 'ordenes_activas_screen.dart';
import 'inventario_screen.dart';
import 'cloud_inventory_screen.dart';

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
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
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
        ],
      ),
    );
  }
}
