import 'package:flutter/material.dart';

import '../../core/services/rescate_sincronizacion_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/database/database_helper.dart';

/// Pantalla de sincronización pendiente: qué tiene este teléfono que la nube
/// no tenga, y el botón para subirlo.
///
/// Existe por un motivo concreto: durante meses la app escribió con el patrón
/// «intento la nube, si falla uso local», y el `catch` solo hacía `debugPrint`,
/// que en release está anulado. Ningún ítem de orden llegó nunca a la nube,
/// ningún abono, y desde el 30/07/2026 tampoco los clientes nuevos.
///
/// La pantalla insiste en una idea: **lo que se ve en el teléfono no prueba
/// nada**. Las cifras de la columna «en la nube» se leen de la nube.
class RescateDatosScreen extends StatefulWidget {
  const RescateDatosScreen({super.key});

  @override
  State<RescateDatosScreen> createState() => _RescateDatosScreenState();
}

class _RescateDatosScreenState extends State<RescateDatosScreen> {
  static const _servicio = RescateSincronizacionService();

  ResultadoRescate? _resultado;
  bool _trabajando = false;
  String _tarea = '';

  @override
  void initState() {
    super.initState();
    _diagnosticar();
  }

  Future<void> _diagnosticar() async {
    setState(() {
      _trabajando = true;
      _tarea = 'Comparando este teléfono con la nube…';
    });
    final r = await _servicio.diagnosticar();
    if (!mounted) return;
    setState(() {
      _resultado = r;
      _trabajando = false;
    });
  }

  Future<void> _subir() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('¿Subir los cambios pendientes?',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Se enviará a la nube lo que hoy solo está en este teléfono. No se '
          'modifica ni se borra nada de lo que ya está guardado allá, y puedes '
          'repetirlo las veces que quieras sin duplicar nada.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Subir'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;

    setState(() {
      _trabajando = true;
      _tarea = 'Subiendo… no cierres la app.';
    });
    final r = await _servicio.subirPendientes();
    if (!mounted) return;
    setState(() {
      _resultado = r;
      _trabajando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultado;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Cambios sin subir'),
        backgroundColor: AppTheme.surface,
      ),
      body: _trabajando && r == null
          ? _cargando()
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _explicacion(),
                  const SizedBox(height: AppTheme.spacingMd),
                  if (DatabaseHelper.ultimoResumenDescarga != null) ...[
                    _tarjetaDescarga(),
                    const SizedBox(height: AppTheme.spacingMd),
                  ],
                  if (r != null) ...[
                    _tarjetaRecuento(r),
                    const SizedBox(height: AppTheme.spacingMd),
                    if (r.ejecutado) ...[
                      _tarjetaVeredicto(r),
                      const SizedBox(height: AppTheme.spacingMd),
                    ],
                    if (r.totalDeOtraCuenta > 0) ...[
                      _tarjetaOtraCuenta(r),
                      const SizedBox(height: AppTheme.spacingMd),
                    ],
                    if (r.totalOmitidas > 0) ...[
                      _tarjetaOmitidas(r),
                      const SizedBox(height: AppTheme.spacingMd),
                    ],
                    if (r.fallos.isNotEmpty) ...[
                      _tarjetaFallos(r),
                      const SizedBox(height: AppTheme.spacingMd),
                    ],
                  ],
                  if (_trabajando) _cargando() else _acciones(r),
                ],
              ),
            ),
    );
  }

  Widget _cargando() => Padding(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppTheme.spacingMd),
            Text(_tarea,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary)),
          ],
        ),
      );

  Widget _explicacion() => _tarjeta(
        icono: Icons.info_outline,
        color: AppTheme.primaryLight,
        titulo: 'Qué es esto',
        hijos: const [
          Text(
            'Cuando el internet falla, la app guarda en el teléfono y sube '
            'después. Aquí ves si algo se quedó sin subir, y puedes forzarlo.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          SizedBox(height: AppTheme.spacingSm),
          Text(
            'La app siempre te muestra los datos de este teléfono, así que '
            'verlos completos en pantalla no significa que estén a salvo. La '
            'columna «en la nube» se lee de la nube.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
      );

  Widget _tarjetaRecuento(ResultadoRescate r) {
    final pendientes = r.totalPendientes;
    return _tarjeta(
      icono: Icons.compare_arrows_rounded,
      color: AppTheme.textPrimary,
      titulo: 'Teléfono contra nube',
      hijos: [
        const Padding(
          padding: EdgeInsets.only(bottom: AppTheme.spacingSm),
          child: Row(
            children: [
              Expanded(flex: 3, child: SizedBox()),
              Expanded(
                child: Text('aquí',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: AppTheme.textTertiary, fontSize: 11)),
              ),
              SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Text('en la nube',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: AppTheme.textTertiary, fontSize: 11)),
              ),
            ],
          ),
        ),
        ...r.tablas.map(_fila),
        const Divider(color: AppTheme.surfaceBorder, height: 24),
        Text(
          pendientes == 0
              ? 'No queda nada por subir.'
              : '$pendientes ${pendientes == 1 ? 'cambio' : 'cambios'} sin subir.',
          style: TextStyle(
            color: pendientes == 0 ? AppTheme.success : AppTheme.warning,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _fila(ConteoTabla t) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Text(t.etiqueta,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ),
            Expanded(
              child: Text('${t.local}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Text('${t.nube}',
                  textAlign: TextAlign.end,
                  style: TextStyle(
                      // Verde no significa «iguales», significa «no falta nada
                      // por subir». La nube puede tener más filas que este
                      // teléfono: vienen de otros dispositivos.
                      color:
                          t.faltantes == 0 ? AppTheme.success : AppTheme.error,
                      fontSize: 13,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

  /// Qué pasó la última vez que la app bajó datos de la nube al teléfono.
  ///
  /// Se muestra porque esa descarga falló en silencio durante meses: si algo
  /// no baja, ahora se ve aquí en vez de perderse en un log que en release no
  /// existe.
  Widget _tarjetaDescarga() => _tarjeta(
        icono: Icons.cloud_download_outlined,
        color: AppTheme.textTertiary,
        titulo: 'Última descarga desde la nube',
        hijos: [
          Text(
            DatabaseHelper.ultimoResumenDescarga!,
            style: const TextStyle(
                color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
          ),
        ],
      );

  Widget _tarjetaOtraCuenta(ResultadoRescate r) => _tarjeta(
        icono: Icons.person_off_outlined,
        color: AppTheme.textTertiary,
        titulo: '${r.totalDeOtraCuenta} filas de otra cuenta',
        hijos: const [
          Text(
            'Este teléfono se usó antes con otra sesión, y quedaron datos de '
            'ese taller guardados aquí. No se suben: cada taller solo puede '
            'subir lo suyo. Tampoco es una pérdida — esos datos están en la '
            'cuenta a la que pertenecen.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      );

  Widget _tarjetaOmitidas(ResultadoRescate r) => _tarjeta(
        icono: Icons.filter_alt_outlined,
        color: AppTheme.textTertiary,
        titulo: '${r.totalOmitidas} filas que no se envían',
        hijos: [
          const Text(
            'Son los datos de ejemplo que la app trae al instalarse y restos '
            'de versiones viejas. Sus identificadores no tienen el formato que '
            'exige la nube, así que nunca podrán subir. No es una pérdida: no '
            'son datos de tu taller.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
        ],
      );

  Widget _tarjetaVeredicto(ResultadoRescate r) {
    final bien = r.completo;
    final extras = <String>[
      if (r.pagosActualizados > 0)
        '${r.pagosActualizados} orden(es) con su estado de pago corregido',
      if (r.repuestosCreados > 0)
        '${r.repuestosCreados} repuesto(s) creados en el inventario de la nube',
    ];
    return _tarjeta(
      icono: bien ? Icons.check_circle_outline : Icons.warning_amber_rounded,
      color: bien ? AppTheme.success : AppTheme.warning,
      titulo: bien ? 'Todo subido' : 'Quedó trabajo sin hacer',
      hijos: [
        Text(
          bien
              ? 'La nube ya tiene todo lo que tiene este teléfono. Verificado '
                  'volviendo a leer de la nube, no de local.'
              : 'Se subió parte, pero la nube todavía no iguala al teléfono. '
                  'No desinstales la app: lo que falta sigue aquí y se puede '
                  'reintentar.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        if (extras.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacingSm),
          Text(extras.join(' · '),
              style:
                  const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _tarjetaFallos(ResultadoRescate r) => _tarjeta(
        icono: Icons.error_outline,
        color: AppTheme.error,
        titulo: 'Lo que no se pudo subir (${r.fallos.length})',
        hijos: [
          const Text(
            'Estos errores antes no se veían: la app los escondía, y por eso el '
            'problema duró meses. Muéstraselos a quien mantiene la app.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          ...r.fallos.take(20).map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacingXs),
                  child: Text('• $f',
                      style: const TextStyle(
                          color: AppTheme.error, fontSize: 12, height: 1.4)),
                ),
              ),
          if (r.fallos.length > 20)
            Text('… y ${r.fallos.length - 20} más.',
                style:
                    const TextStyle(color: AppTheme.textTertiary, fontSize: 12)),
        ],
      );

  Widget _acciones(ResultadoRescate? r) {
    final hayPendientes = r != null && r.totalPendientes > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingMd),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
          icon: const Icon(Icons.cloud_upload_outlined),
          label: Text(hayPendientes
              ? 'Subir lo que falta'
              : 'Subir de nuevo (no duplica nada)'),
          onPressed: _subir,
        ),
        const SizedBox(height: AppTheme.spacingSm),
        OutlinedButton.icon(
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text('Volver a comparar'),
          onPressed: _diagnosticar,
        ),
      ],
    );
  }

  Widget _tarjeta({
    required IconData icono,
    required Color color,
    required String titulo,
    required List<Widget> hijos,
  }) =>
      Container(
        decoration: AppTheme.elevatedCardDecoration,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, color: color, size: 22),
                  const SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(color: AppTheme.surfaceBorder, height: 24),
              ...hijos,
            ],
          ),
        ),
      );
}
