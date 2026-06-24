import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/inventario_provider.dart';

/// Modal para simular el escaneo de un código de barras.
///
/// Permite al usuario seleccionar códigos de barra ficticios o escribir uno
/// para simular la cámara y buscar el repuesto correspondiente.
class EscanerSimuladoDialog extends StatefulWidget {
  const EscanerSimuladoDialog({super.key});

  @override
  State<EscanerSimuladoDialog> createState() => _EscanerSimuladoDialogState();
}

class _EscanerSimuladoDialogState extends State<EscanerSimuladoDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _laserAnimation;
  String? _errorMessage;

  // Lista de códigos preestablecidos (de la semilla) para pruebas rápidas
  final List<Map<String, String>> _codigosDemo = [
    {'label': 'Pastillas Brembo', 'code': 'FRE-001'},
    {'label': 'Bujía NGK CR9EIX', 'code': 'MOT-002'},
    {'label': 'Aceite Motul 4T 10W40', 'code': 'LUB-001'},
    {'label': 'Kit Arrastre DID (Sin Stock)', 'code': 'TRA-001'},
    {'label': 'Código inexistente', 'code': 'ERR-999'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _procesarCodigo(String codigo) async {
    setState(() {
      _errorMessage = null;
    });

    final provider = context.read<InventarioProvider>();
    final repuesto = await provider.buscarPorCodigo(codigo);

    if (repuesto != null) {
      if (mounted) {
        Navigator.pop(context, repuesto);
      }
    } else {
      setState(() {
        _errorMessage = 'Código "$codigo" no encontrado en inventario';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: AppTheme.elevatedCardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppTheme.primaryLight,
                  size: 24,
                ),
                const SizedBox(width: AppTheme.spacingSm),
                const Text(
                  'Escáner Simulado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppTheme.textTertiary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                )
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Visor de Cámara Simulado
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(color: AppTheme.surfaceBorder),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Cuadrícula / Patrón de cámara
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.15,
                      child: GridPaper(
                        color: Colors.blueGrey,
                        interval: 40,
                        subdivisions: 1,
                        child: Container(),
                      ),
                    ),
                  ),

                  // Caja de enfoque del código de barras
                  Container(
                    width: 240,
                    height: 90,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _errorMessage != null ? AppTheme.error : AppTheme.primaryLight,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.barcode_reader,
                        color: AppTheme.textTertiary,
                        size: 40,
                      ),
                    ),
                  ),

                  // Línea Láser Animada
                  AnimatedBuilder(
                    animation: _laserAnimation,
                    builder: (context, child) {
                      final topOffset = 35 + (_laserAnimation.value * 90);
                      return Positioned(
                        top: topOffset,
                        left: (MediaQuery.of(context).size.width - 240) / 2 - 16,
                        child: Container(
                          width: 240,
                          height: 2,
                          decoration: BoxDecoration(
                            color: _errorMessage != null ? AppTheme.error : Colors.cyanAccent,
                            boxShadow: [
                              BoxShadow(
                                color: _errorMessage != null
                                    ? AppTheme.error.withOpacity(0.8)
                                    : Colors.cyanAccent.withOpacity(0.8),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Texto de instrucción
                  const Positioned(
                    bottom: 12,
                    child: Text(
                      'Coloque el código de barras en el recuadro',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),

            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.errorSurface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.error,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Entrada Manual
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Ingresar código manual...',
                      prefixIcon: Icon(Icons.keyboard_outlined, color: AppTheme.textTertiary),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                ElevatedButton(
                  onPressed: () {
                    if (_controller.text.trim().isNotEmpty) {
                      _procesarCodigo(_controller.text.trim().toUpperCase());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            const Text(
              'Códigos rápidos de prueba:',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppTheme.spacingXs),

            // Botones de acceso rápido para demostración
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _codigosDemo.map((item) {
                return ActionChip(
                  label: Text(
                    '${item['label']} (${item['code']})',
                    style: const TextStyle(fontSize: 11),
                  ),
                  backgroundColor: AppTheme.surfaceLight,
                  side: const BorderSide(color: AppTheme.surfaceBorder),
                  onPressed: () {
                    _controller.text = item['code']!;
                    _procesarCodigo(item['code']!);
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
