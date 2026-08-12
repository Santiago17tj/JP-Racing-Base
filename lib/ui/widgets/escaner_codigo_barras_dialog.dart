import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/inventario_provider.dart';
import '../../data/models/repuesto.dart';
import '../screens/agregar_repuesto_screen.dart';

/// Diálogo de escáner de código de barras real usando la cámara del dispositivo.
///
/// Retorna un [Repuesto] si se encuentra el código en inventario,
/// o null si el usuario cancela. Conserva la misma interfaz del antiguo
/// EscanerSimuladoDialog para mantener compatibilidad con las pantallas existentes.
class EscanerCodigoBarrasDialog extends StatefulWidget {
  const EscanerCodigoBarrasDialog({super.key});

  @override
  State<EscanerCodigoBarrasDialog> createState() =>
      _EscanerCodigoBarrasDialogState();
}

class _EscanerCodigoBarrasDialogState extends State<EscanerCodigoBarrasDialog> {
  final TextEditingController _manualController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _procesando = false;
  bool _usandoManual = false;
  String? _errorMessage;
  String? _ultimoCodigo;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualController.dispose();
    super.dispose();
  }

  /// Procesa un código escaneado o ingresado manualmente.
  Future<void> _procesarCodigo(String codigo) async {
    // Evitar procesar el mismo código dos veces seguidas o mientras se procesa otro.
    if (_procesando || codigo == _ultimoCodigo) return;

    setState(() {
      _procesando = true;
      _errorMessage = null;
      _ultimoCodigo = codigo;
    });

    HapticFeedback.mediumImpact();

    final provider = context.read<InventarioProvider>();
    final repuesto = await provider.buscarPorCodigo(codigo);

    if (!mounted) return;

    if (repuesto != null) {
      Navigator.pop(context, repuesto);
      return;
    }

    // Código no encontrado — ofrecer crear el repuesto
    final crear = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.warning),
            SizedBox(width: 10),
            Text('Código no registrado'),
          ],
        ),
        content: Text(
          'El repuesto con código "$codigo" no existe en tu inventario. '
          '¿Deseas crearlo ahora?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary),
            child: const Text('Crear Repuesto'),
          ),
        ],
      ),
    );

    if (crear == true && mounted) {
      Navigator.pop(context); // Cerrar escáner
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              AgregarRepuestoScreen(codigoPrefill: codigo),
        ),
      );
    } else {
      setState(() {
        _procesando = false;
        _ultimoCodigo = null; // Permitir re-escanear
        _errorMessage = 'Código "$codigo" no encontrado en inventario';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding:
          const EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacingLg),
        decoration: AppTheme.elevatedCardDecoration,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Título ──────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.qr_code_scanner_rounded,
                    color: AppTheme.primaryLight, size: 24),
                const SizedBox(width: AppTheme.spacingSm),
                const Expanded(
                  child: Text(
                    'Escáner de Código',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                // Botón de linterna
                ValueListenableBuilder(
                  valueListenable: _scannerController,
                  builder: (context, state, child) {
                    if (_usandoManual) return const SizedBox.shrink();
                    return IconButton(
                      icon: Icon(
                        state.torchState == TorchState.on
                            ? Icons.flash_on_rounded
                            : Icons.flash_off_rounded,
                        color: state.torchState == TorchState.on
                            ? AppTheme.warning
                            : AppTheme.textTertiary,
                      ),
                      onPressed: () => _scannerController.toggleTorch(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Linterna',
                    );
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: AppTheme.textTertiary),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // ── Visor de cámara ─────────────────────────────
            if (!_usandoManual)
              Container(
                height: 220,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.surfaceBorder),
                ),
                child: Stack(
                  children: [
                    MobileScanner(
                      controller: _scannerController,
                      onDetect: (capture) {
                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty) {
                          final code = barcodes.first.rawValue;
                          if (code != null && code.isNotEmpty) {
                            _procesarCodigo(code.toUpperCase());
                          }
                        }
                      },
                    ),
                    // Overlay con recuadro de enfoque
                    Center(
                      child: Container(
                        width: 240,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: _procesando
                                ? AppTheme.warning
                                : _errorMessage != null
                                    ? AppTheme.error
                                    : AppTheme.primaryLight,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusSm),
                        ),
                      ),
                    ),
                    // Indicador de procesamiento
                    if (_procesando)
                      const Center(
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryLight,
                          strokeWidth: 2,
                        ),
                      ),
                    // Instrucción
                    const Positioned(
                      bottom: 12,
                      left: 0,
                      right: 0,
                      child: Text(
                        'Apunte al código de barras',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),

            if (!_usandoManual) const SizedBox(height: AppTheme.spacingSm),

            // ── Error message ───────────────────────────────
            if (_errorMessage != null)
              Container(
                margin:
                    const EdgeInsets.only(bottom: AppTheme.spacingSm),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.errorSurface,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSm),
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

            // ── Toggle entre cámara y entrada manual ────────
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _usandoManual = !_usandoManual;
                  _errorMessage = null;
                  _ultimoCodigo = null;
                  _procesando = false;
                });
              },
              icon: Icon(
                _usandoManual
                    ? Icons.camera_alt_rounded
                    : Icons.keyboard_rounded,
                size: 18,
              ),
              label: Text(
                _usandoManual
                    ? 'Usar cámara'
                    : 'Ingresar código manual',
                style: const TextStyle(fontSize: 13),
              ),
            ),

            // ── Entrada manual ──────────────────────────────
            if (_usandoManual) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _manualController,
                      decoration: const InputDecoration(
                        hintText: 'Ingresar código manual...',
                        prefixIcon: Icon(Icons.keyboard_outlined,
                            color: AppTheme.textTertiary),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(fontSize: 14),
                      onSubmitted: (value) {
                        if (value.trim().isNotEmpty) {
                          _procesarCodigo(value.trim().toUpperCase());
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacingSm),
                  ElevatedButton(
                    onPressed: () {
                      if (_manualController.text.trim().isNotEmpty) {
                        _procesarCodigo(
                            _manualController.text.trim().toUpperCase());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: const Icon(Icons.arrow_forward_rounded),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
