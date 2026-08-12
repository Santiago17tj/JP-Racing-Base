import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/repuesto.dart';
import '../../data/providers/inventario_provider.dart';

class IdentificarIaDialog extends StatefulWidget {
  const IdentificarIaDialog({super.key});

  @override
  State<IdentificarIaDialog> createState() => _IdentificarIaDialogState();
}

class _IdentificarIaDialogState extends State<IdentificarIaDialog> {
  static const _geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  bool _analyzing = false;
  String? _errorMessage;

  // Resultado estructurado de la IA
  String? _nombreRepuesto;
  String? _probabilidadFalla;
  String? _gravedad;
  String? _sugerenciaReparacion;
  Repuesto? _foundRepuesto;

  Future<void> _captureImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() {
        _imageFile = image;
        _analyzing = true;
        _errorMessage = null;
        _nombreRepuesto = null;
        _probabilidadFalla = null;
        _gravedad = null;
        _sugerenciaReparacion = null;
        _foundRepuesto = null;
      });

      await _analyzeWithGemini(image);
    } catch (e) {
      setState(() {
        _analyzing = false;
        _errorMessage = 'Error al capturar/analizar la imagen: $e';
      });
    }
  }

  Future<void> _analyzeWithGemini(XFile image) async {
    try {
      final model = GenerativeModel(
        model: 'gemini-2.5-flash',
        apiKey: _geminiApiKey.trim(),
        systemInstruction: Content.system(
          'Eres un analista automotriz experto del taller Mecanix, '
          'especializado en motocicletas y vehículos automotores. '
          'Tu única función es analizar imágenes de piezas, repuestos o componentes '
          'de motocicletas y vehículos para identificarlos con precisión. '
          'SIEMPRE debes responder ÚNICAMENTE con un objeto JSON válido (sin markdown, sin backticks, sin texto adicional) '
          'con exactamente estas 4 claves: '
          '"nombre_repuesto" (nombre comercial del repuesto identificado), '
          '"probabilidad_falla" (porcentaje estimado de falla si la pieza muestra desgaste, ej. "75%"), '
          '"gravedad" (una de: "Baja", "Media", "Alta", "Crítica"), '
          '"sugerencia_reparacion" (breve instrucción de qué hacer con la pieza). '
          'Si la imagen NO es de un repuesto automotriz, responde con: '
          '{"nombre_repuesto":"No identificado","probabilidad_falla":"N/A","gravedad":"N/A","sugerencia_reparacion":"La imagen no corresponde a un repuesto automotriz. Tome una foto de la pieza."}',
        ),
      );

      final bytes = await image.readAsBytes();
      final mimeType = image.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';

      final response = await model.generateContent([
        Content.multi([
          TextPart('Identifica este repuesto o pieza automotriz. Responde SOLO con JSON válido.'),
          DataPart(mimeType, bytes),
        ]),
      ]);

      if (!mounted) return;

      final text = response.text?.trim() ?? '';
      debugPrint('🤖 Respuesta Gemini: $text');

      // Limpiar posibles backticks de markdown
      String cleanJson = text;
      if (cleanJson.startsWith('```')) {
        cleanJson = cleanJson.replaceAll(RegExp(r'^```(?:json)?\s*'), '').replaceAll(RegExp(r'\s*```$'), '');
      }

      final Map<String, dynamic> result = json.decode(cleanJson);

      final nombre = result['nombre_repuesto'] as String? ?? 'Desconocido';

      // Buscar coincidencia en inventario
      final inventario = context.read<InventarioProvider>();
      Repuesto? matched;
      final palabrasClave = nombre.toLowerCase().split(' ');
      for (final r in inventario.repuestos) {
        final nombreLower = r.nombre.toLowerCase();
        for (final palabra in palabrasClave) {
          if (palabra.length > 3 && nombreLower.contains(palabra)) {
            matched = r;
            break;
          }
        }
        if (matched != null) break;
      }

      setState(() {
        _analyzing = false;
        _nombreRepuesto = nombre;
        _probabilidadFalla = result['probabilidad_falla'] as String? ?? 'N/A';
        _gravedad = result['gravedad'] as String? ?? 'N/A';
        _sugerenciaReparacion = result['sugerencia_reparacion'] as String? ?? 'Sin sugerencia';
        _foundRepuesto = matched;
      });
    } catch (e) {
      debugPrint('❌ Error Gemini: $e');
      if (!mounted) return;
      setState(() {
        _analyzing = false;
        if (e.toString().contains('503') || e.toString().contains('high demand')) {
          _errorMessage = 'El servidor de IA de Google está experimentando alta demanda momentánea. Por favor, intenta de nuevo en unos segundos.';
        } else {
          _errorMessage = 'Error al analizar con IA: ${e.toString().replaceAll('Exception: ', '')}';
        }
      });
    }
  }

  Color _colorForGravedad(String gravedad) {
    switch (gravedad.toLowerCase()) {
      case 'crítica': return AppTheme.error;
      case 'alta':    return const Color(0xFFEF4444);
      case 'media':   return AppTheme.warning;
      case 'baja':    return AppTheme.success;
      default:        return AppTheme.textTertiary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacingLg),
          decoration: AppTheme.elevatedCardDecoration,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: AppTheme.primaryLight, size: 24),
                  const SizedBox(width: AppTheme.spacingSm),
                  const Expanded(
                    child: Text(
                      'Mecanix IA Vision',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppTheme.textTertiary),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                ],
              ),
              const SizedBox(height: AppTheme.spacingMd),

              if (_imageFile == null && !_analyzing) ...[
                // Estado inicial
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.surfaceBorder),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_outlined, size: 40, color: AppTheme.textTertiary),
                      SizedBox(height: 12),
                      Text('Toma una foto de la pieza física',
                        style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold)),
                      Text('Gemini Vision analizará y sugerirá el producto.',
                        style: TextStyle(color: AppTheme.textTertiary, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingLg),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _captureImage(ImageSource.camera),
                        icon: const Icon(Icons.photo_camera_rounded, color: Colors.white),
                        label: const Text('CÁMARA', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _captureImage(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_rounded, color: AppTheme.textPrimary),
                        label: const Text('GALERÍA', style: TextStyle(color: AppTheme.textPrimary)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: AppTheme.surfaceBorder),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_analyzing) ...[
                // Analizando con Gemini
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: Colors.cyanAccent),
                      const SizedBox(height: 16),
                      const Text(
                        'Gemini Vision analizando...',
                        style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold, fontSize: 14),
                      ).animate(onPlay: (c) => c.repeat(reverse: true))
                       .fadeIn(duration: 600.ms)
                       .scale(end: const Offset(1.05, 1.05)),
                      const SizedBox(height: 4),
                      const Text(
                        'Extrayendo patrones visuales del repuesto',
                        style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ] else if (_nombreRepuesto != null) ...[
                // Resultado de IA
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ANÁLISIS MECANIX IA 🤖',
                        style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 10),
                      // Nombre del repuesto
                      Text(
                        _nombreRepuesto!,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: AppTheme.textPrimary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Divider(color: AppTheme.surfaceBorder, height: 20),
                      // Grid de datos
                      Row(
                        children: [
                          Expanded(
                            child: _InfoTile(
                              label: 'PROBABILIDAD FALLA',
                              value: _probabilidadFalla ?? 'N/A',
                              color: AppTheme.warning,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoTile(
                              label: 'GRAVEDAD',
                              value: _gravedad ?? 'N/A',
                              color: _colorForGravedad(_gravedad ?? ''),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Sugerencia
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primarySurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('SUGERENCIA DE REPARACIÓN', style: TextStyle(color: AppTheme.primaryLight, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                            const SizedBox(height: 4),
                            Text(
                              _sugerenciaReparacion ?? '',
                              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      // Estado de inventario
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _foundRepuesto != null ? AppTheme.successSurface : AppTheme.warningSurface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _foundRepuesto != null ? Icons.inventory_2_rounded : Icons.warning_amber_rounded,
                              color: _foundRepuesto != null ? AppTheme.success : AppTheme.warning,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _foundRepuesto != null
                                    ? 'En Stock: ${_foundRepuesto!.stockActual} unidades — ${CurrencyFormatter.format(_foundRepuesto!.precioVenta)}'
                                    : 'No registrado en inventario local',
                                style: TextStyle(
                                  color: _foundRepuesto != null ? AppTheme.success : AppTheme.warning,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spacingMd),
                if (_foundRepuesto != null)
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, _foundRepuesto),
                    icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white),
                    label: const Text('AÑADIR A LA VENTA / COTIZACIÓN', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Usa "Agregar repuesto" para registrar $_nombreRepuesto')),
                      );
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white),
                    label: const Text('REGISTRAR EN INVENTARIO', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _imageFile = null;
                      _nombreRepuesto = null;
                      _foundRepuesto = null;
                    });
                  },
                  child: const Text('Tomar otra foto', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(_errorMessage!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () => setState(() { _imageFile = null; _errorMessage = null; }),
                  child: const Text('Reintentar'),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile informativo reutilizable para el resultado de la IA
class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _InfoTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
