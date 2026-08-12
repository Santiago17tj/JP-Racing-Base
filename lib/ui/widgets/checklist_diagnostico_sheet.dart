import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// Estado posible de cada punto de inspección de la moto.
enum EstadoPunto {
  bien('Bien', AppTheme.success, Icons.check_circle_rounded),
  revisar('Revisar', AppTheme.warning, Icons.error_outline_rounded),
  cambiar('Cambiar', AppTheme.error, Icons.build_circle_rounded);

  const EstadoPunto(this.label, this.color, this.icono);

  final String label;
  final Color color;
  final IconData icono;

  static EstadoPunto? fromLabel(String value) {
    final v = value.trim().toLowerCase();
    for (final e in EstadoPunto.values) {
      if (e.label.toLowerCase() == v) return e;
    }
    return null;
  }
}

/// Grupo de puntos de inspección (un sistema de la moto).
class _SistemaMoto {
  const _SistemaMoto(this.nombre, this.icono, this.puntos);

  final String nombre;
  final IconData icono;
  final List<String> puntos;
}

/// Catálogo de revisión estándar de una motocicleta.
const List<_SistemaMoto> _sistemasMoto = [
  _SistemaMoto('Motor', Icons.settings_rounded, [
    'Aceite de motor',
    'Filtro de aceite',
    'Bujía',
    'Filtro de aire',
    'Fugas / empaques',
    'Ruido anormal',
    'Carburación / inyección',
  ]),
  _SistemaMoto('Frenos', Icons.disc_full_rounded, [
    'Pastillas delanteras',
    'Pastillas / bandas traseras',
    'Disco delantero',
    'Disco trasero',
    'Líquido de frenos',
    'Guaya / bomba de freno',
  ]),
  _SistemaMoto('Transmisión', Icons.link_rounded, [
    'Cadena',
    'Piñón / sprocket',
    'Clutch',
    'Guaya de clutch',
    'Cambios',
  ]),
  _SistemaMoto('Eléctrico', Icons.bolt_rounded, [
    'Batería',
    'Luz delantera',
    'Stop / luz trasera',
    'Direccionales',
    'Pito',
    'Arranque eléctrico',
    'Tablero / testigos',
  ]),
  _SistemaMoto('Suspensión y dirección', Icons.compress_rounded, [
    'Barras / telescópicos',
    'Amortiguadores traseros',
    'Rodamientos de dirección',
    'Tijera',
  ]),
  _SistemaMoto('Llantas y rines', Icons.trip_origin_rounded, [
    'Llanta delantera',
    'Llanta trasera',
    'Rin delantero',
    'Rin trasero',
    'Presión de aire',
  ]),
  _SistemaMoto('Carrocería y otros', Icons.two_wheeler_rounded, [
    'Carenaje / carátula',
    'Espejos',
    'Manubrio',
    'Asiento',
    'Guardabarros',
    'Tanque de gasolina',
    'Documentos / accesorios',
  ]),
];

const String _tituloBloque = 'ESTADO DE LA MOTO:';

/// Hoja de inspección: permite marcar qué tiene la moto por sistema y
/// genera automáticamente el texto del diagnóstico técnico.
///
/// Recibe el diagnóstico actual y devuelve el texto actualizado, o `null`
/// si el usuario cancela.
class ChecklistDiagnosticoSheet extends StatefulWidget {
  const ChecklistDiagnosticoSheet({super.key, required this.diagnosticoActual});

  final String diagnosticoActual;

  static Future<String?> mostrar(
      BuildContext context, String diagnosticoActual) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          ChecklistDiagnosticoSheet(diagnosticoActual: diagnosticoActual),
    );
  }

  /// Separa un diagnóstico guardado en (puntos marcados, texto libre restante).
  /// Así la hoja se puede reabrir conservando lo que ya se había marcado y
  /// cualquier nota escrita a mano (incluidos los conceptos de mano de obra).
  static (Map<String, EstadoPunto>, String) parsear(String diagnostico) {
    final seleccion = <String, EstadoPunto>{};
    final resto = <String>[];

    final puntosValidos = <String>{
      for (final sistema in _sistemasMoto) ...sistema.puntos,
    };
    final encabezados = <String>{
      _tituloBloque,
      for (final sistema in _sistemasMoto) '${sistema.nombre}:',
    };

    for (final linea in diagnostico.split('\n')) {
      final limpia = linea.trim();
      if (limpia.isEmpty) {
        resto.add(linea);
        continue;
      }
      if (encabezados.contains(limpia)) continue;

      if (limpia.startsWith('•')) {
        final sinVinieta = limpia.substring(1).trim();
        final sep = sinVinieta.lastIndexOf(':');
        if (sep > 0) {
          final punto = sinVinieta.substring(0, sep).trim();
          final estado = EstadoPunto.fromLabel(sinVinieta.substring(sep + 1));
          if (estado != null && puntosValidos.contains(punto)) {
            seleccion[punto] = estado;
            continue;
          }
        }
      }
      resto.add(linea);
    }

    return (seleccion, resto.join('\n').trim());
  }

  /// Arma el texto final del diagnóstico a partir de lo marcado y las notas.
  static String construirTexto(
      Map<String, EstadoPunto> seleccion, String textoLibre) {
    final buffer = StringBuffer();

    final conMarcas = _sistemasMoto
        .where((s) => s.puntos.any(seleccion.containsKey))
        .toList();

    if (conMarcas.isNotEmpty) {
      buffer.writeln(_tituloBloque);
      for (final sistema in conMarcas) {
        buffer.writeln('${sistema.nombre}:');
        for (final punto in sistema.puntos) {
          final estado = seleccion[punto];
          if (estado != null) buffer.writeln('• $punto: ${estado.label}');
        }
      }
    }

    final libre = textoLibre.trim();
    if (libre.isNotEmpty) {
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.writeln(libre);
    }

    return buffer.toString().trim();
  }

  @override
  State<ChecklistDiagnosticoSheet> createState() =>
      _ChecklistDiagnosticoSheetState();
}

class _ChecklistDiagnosticoSheetState extends State<ChecklistDiagnosticoSheet> {
  late final Map<String, EstadoPunto> _seleccion;
  late final TextEditingController _notasCtrl;

  @override
  void initState() {
    super.initState();
    final (seleccion, textoLibre) =
        ChecklistDiagnosticoSheet.parsear(widget.diagnosticoActual);
    _seleccion = Map.of(seleccion);
    _notasCtrl = TextEditingController(text: textoLibre);
  }

  @override
  void dispose() {
    _notasCtrl.dispose();
    super.dispose();
  }

  void _marcar(String punto, EstadoPunto estado) {
    HapticFeedback.selectionClick();
    setState(() {
      // Volver a tocar el mismo estado desmarca el punto.
      if (_seleccion[punto] == estado) {
        _seleccion.remove(punto);
      } else {
        _seleccion[punto] = estado;
      }
    });
  }

  void _aplicar() {
    HapticFeedback.mediumImpact();
    Navigator.pop(
      context,
      ChecklistDiagnosticoSheet.construirTexto(_seleccion, _notasCtrl.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final marcados = _seleccion.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
            border: Border(
              top: BorderSide(color: AppTheme.surfaceBorder),
              left: BorderSide(color: AppTheme.surfaceBorder),
              right: BorderSide(color: AppTheme.surfaceBorder),
            ),
          ),
          child: Column(
            children: [
              // ── Encabezado ──
              Container(
                padding: const EdgeInsets.fromLTRB(AppTheme.spacingMd,
                    AppTheme.spacingSm, AppTheme.spacingSm, AppTheme.spacingSm),
                decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: AppTheme.surfaceBorder)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBorder,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.two_wheeler_rounded,
                            color: AppTheme.primaryLight),
                        const SizedBox(width: AppTheme.spacingSm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '¿Qué tiene la moto?',
                                style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                marcados == 0
                                    ? 'Marca el estado de cada punto revisado'
                                    : '$marcados ${marcados == 1 ? "punto marcado" : "puntos marcados"}',
                                style: const TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar',
                          icon: const Icon(Icons.close_rounded,
                              color: AppTheme.textSecondary),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Listado de sistemas ──
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppTheme.spacingMd),
                  children: [
                    ..._sistemasMoto.map(_buildSistemaCard),
                    const SizedBox(height: AppTheme.spacingMd),
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      decoration: AppTheme.cardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.notes_rounded,
                                  size: 16, color: AppTheme.primaryLight),
                              SizedBox(width: 8),
                              Text(
                                'OBSERVACIONES ADICIONALES',
                                style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingSm),
                          TextField(
                            controller: _notasCtrl,
                            maxLines: 4,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText:
                                  'Detalles del diagnóstico, trabajos sugeridos...',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),

              // ── Acciones ──
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: const BoxDecoration(
                  color: AppTheme.surface,
                  border:
                      Border(top: BorderSide(color: AppTheme.surfaceBorder)),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: _seleccion.isEmpty
                            ? null
                            : () => setState(_seleccion.clear),
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: const Text('Limpiar'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: AppTheme.spacingSm),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _aplicar,
                          icon: const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18),
                          label: const Text(
                            'APLICAR AL DIAGNÓSTICO',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSistemaCard(_SistemaMoto sistema) {
    final marcadosSistema = sistema.puntos.where(_seleccion.containsKey).length;

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm + 4),
      decoration: AppTheme.cardDecoration,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: marcadosSistema > 0,
          iconColor: AppTheme.primaryLight,
          collapsedIconColor: AppTheme.textTertiary,
          leading: Icon(sistema.icono, size: 20, color: AppTheme.primaryLight),
          title: Text(
            sistema.nombre,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            marcadosSistema == 0
                ? 'Sin revisar'
                : '$marcadosSistema de ${sistema.puntos.length} marcados',
            style: TextStyle(
              color: marcadosSistema == 0
                  ? AppTheme.textTertiary
                  : AppTheme.primaryLight,
              fontSize: 11,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
              AppTheme.spacingMd, 0, AppTheme.spacingMd, AppTheme.spacingSm),
          children: sistema.puntos.map(_buildPuntoRow).toList(),
        ),
      ),
    );
  }

  Widget _buildPuntoRow(String punto) {
    final actual = _seleccion[punto];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              punto,
              style: TextStyle(
                color: actual == null
                    ? AppTheme.textSecondary
                    : AppTheme.textPrimary,
                fontSize: 13,
                fontWeight:
                    actual == null ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacingSm),
          ...EstadoPunto.values.map((estado) {
            final activo = actual == estado;
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: InkWell(
                onTap: () => _marcar(punto, estado),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: activo
                        ? estado.color.withValues(alpha: 0.18)
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(
                      color: activo ? estado.color : AppTheme.surfaceBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        estado.icono,
                        size: 13,
                        color: activo ? estado.color : AppTheme.textTertiary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        estado.label,
                        style: TextStyle(
                          color: activo ? estado.color : AppTheme.textTertiary,
                          fontSize: 10,
                          fontWeight:
                              activo ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
