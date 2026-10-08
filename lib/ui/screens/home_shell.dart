import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/sesion_local_provider.dart';
import '../../data/providers/taller_provider.dart';
import 'ordenes_activas_screen.dart';
import 'inventario_screen.dart';
import 'contabilidad_screen.dart';
import 'ajustes_taller_screen.dart';
import '../widgets/aviso_sincronizacion.dart';

/// Contenedor principal de la aplicación con navegación inferior.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Seccion {
  final String etiqueta;
  final IconData icono;
  final IconData iconoActivo;
  final Widget pantalla;
  final bool soloAdministrador;

  const _Seccion(this.etiqueta, this.icono, this.iconoActivo, this.pantalla,
      {this.soloAdministrador = false});
}

class _HomeShellState extends State<HomeShell> {
  // Se recuerda por nombre y no por posición: al entrar o salir del modo
  // mecánico cambia el número de pestañas y un índice apuntaría a otra.
  String _actual = 'Servicios';
  bool _sinSesion = false;

  // «Caja» ocupa el sitio de la antigua pestaña «Cloud», que era un duplicado
  // del inventario con un botón de borrar que el modo mecánico no ocultaba.
  static const _secciones = [
    _Seccion('Servicios', Icons.build_circle_outlined,
        Icons.build_circle_rounded, OrdenesActivasScreen()),
    _Seccion('Inventario', Icons.inventory_2_outlined,
        Icons.inventory_2_rounded, InventarioScreen()),
    _Seccion('Caja', Icons.point_of_sale_outlined, Icons.point_of_sale_rounded,
        ContabilidadScreen(),
        soloAdministrador: true),
    _Seccion('Ajustes', Icons.settings_outlined, Icons.settings_rounded,
        AjustesTallerScreen()),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final tallerProvider = Provider.of<TallerProvider>(context, listen: false);
      if (tallerProvider.taller != null) return;
      final uid = auth.currentUserId;
      if (uid == null) {
        setState(() => _sinSesion = true);
        return;
      }
      await tallerProvider.cargarTaller(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final verFinanzas = context.watch<SesionLocalProvider>().puedeVerFinanzas;
    final visibles = _secciones
        .where((s) => !s.soloAdministrador || verFinanzas)
        .toList();
    final encontrada = visibles.indexWhere((s) => s.etiqueta == _actual);
    final indice = encontrada == -1 ? 0 : encontrada;

    return Consumer<TallerProvider>(
      builder: (context, tallerProvider, _) {
        if (tallerProvider.taller == null && _sinSesion) {
          return _SinSesion(
            onVolver: () =>
                Provider.of<AuthProvider>(context, listen: false).signOut(),
          );
        }
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
                  CircularProgressIndicator(color: AppTheme.primary),
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
                  index: indice,
                  children: [
                    for (final s in visibles)
                      KeyedSubtree(key: ValueKey(s.etiqueta), child: s.pantalla),
                  ],
                ),
              ),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppTheme.surfaceBorder)),
            ),
            child: BottomNavigationBar(
              currentIndex: indice,
              onTap: (index) =>
                  setState(() => _actual = visibles[index].etiqueta),
              type: BottomNavigationBarType.fixed,
              items: [
                for (final s in visibles)
                  BottomNavigationBarItem(
                    icon: Icon(s.icono),
                    activeIcon: Icon(s.iconoActivo),
                    label: s.etiqueta,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SinSesion extends StatelessWidget {
  final VoidCallback onVolver;

  const _SinSesion({required this.onVolver});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_clock_outlined,
                  size: 48, color: AppTheme.textTertiary),
              const SizedBox(height: AppTheme.spacingMd),
              Text('La sesión se cerró',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppTheme.spacingSm),
              const Text(
                'Tus datos siguen guardados en el teléfono. Vuelve a entrar '
                'con tu cuenta para seguir trabajando.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.spacingLg),
              ElevatedButton(
                onPressed: onVolver,
                child: const Text('Volver a iniciar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
