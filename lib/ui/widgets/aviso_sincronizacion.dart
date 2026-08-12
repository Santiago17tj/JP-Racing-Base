import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../core/services/rescate_sincronizacion_service.dart';
import '../../core/theme/app_theme.dart';
import '../screens/rescate_datos_screen.dart';

/// Franja de aviso: «N cambios sin subir», con acceso directo a reintentar.
///
/// Es la pieza que faltaba. La app escribe con el patrón «intento la nube, si
/// falla uso local», y durante meses cada fallo se perdió en un `catch` con
/// `debugPrint` anulado en release: el cliente veía todo bien en su pantalla
/// mientras la nube se quedaba vacía.
///
/// El aviso no se fía de que cada `catch` haya anotado su error: **cuenta filas
/// del teléfono contra filas de la nube**. Un fallo que nadie registró aparece
/// igual como diferencia.
///
/// Se calla solo si no hay nada pendiente o si no se puede comprobar, para no
/// inventarle alarmas al mecánico.
class AvisoSincronizacion extends StatefulWidget {
  const AvisoSincronizacion({super.key});

  @override
  State<AvisoSincronizacion> createState() => _AvisoSincronizacionState();
}

class _AvisoSincronizacionState extends State<AvisoSincronizacion>
    with WidgetsBindingObserver {
  static const _servicio = RescateSincronizacionService();

  int _pendientes = 0;
  bool _comprobando = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _comprobar());
  }

  @override
  void dispose() {
    if (!kIsWeb) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver a la app puede haber vuelto el internet: vale la pena mirar.
    if (state == AppLifecycleState.resumed) _comprobar();
  }

  Future<void> _comprobar() async {
    if (kIsWeb || _comprobando) return;
    _comprobando = true;
    final n = await _servicio.contarPendientes();
    _comprobando = false;
    if (!mounted || n == _pendientes) return;
    setState(() => _pendientes = n);
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || _pendientes == 0) return const SizedBox.shrink();

    return Material(
      color: AppTheme.warningSurface,
      child: InkWell(
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RescateDatosScreen()),
          );
          await _comprobar();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacingMd, vertical: AppTheme.spacingSm),
          child: Row(
            children: [
              const Icon(Icons.cloud_off_rounded,
                  color: AppTheme.warning, size: 20),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text(
                  _pendientes == 1
                      ? '1 cambio sin subir a la nube'
                      : '$_pendientes cambios sin subir a la nube',
                  style: const TextStyle(
                    color: AppTheme.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Text(
                'Revisar',
                style: TextStyle(
                    color: AppTheme.warning,
                    fontSize: 13,
                    fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.warning, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
