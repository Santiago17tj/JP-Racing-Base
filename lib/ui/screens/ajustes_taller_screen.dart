import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/supabase_service.dart';
import '../../data/providers/auth_provider.dart';
import '../../data/providers/taller_provider.dart';
import 'contabilidad_screen.dart';
import 'recordatorios_screen.dart';
import 'rescate_datos_screen.dart';
import '../../core/services/respaldo_service.dart';
import '../../data/providers/sesion_local_provider.dart';

/// Pantalla premium para gestionar los ajustes de perfil, identidad visual y facturación del taller.
class AjustesTallerScreen extends StatefulWidget {
  const AjustesTallerScreen({super.key});

  @override
  State<AjustesTallerScreen> createState() => _AjustesTallerScreenState();
}

class _AjustesTallerScreenState extends State<AjustesTallerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late TextEditingController _nombreController;
  late TextEditingController _telefonoController;
  late TextEditingController _direccionController;
  late TextEditingController _ciudadController;
  late TextEditingController _impuestoController;
  late TextEditingController _terminosController;

  String _monedaSeleccionada = 'COP';
  bool _exportando = false;
  String? _logoUrl;
  bool _subiendoLogo = false;

  final List<Map<String, String>> _monedas = [
    {'code': 'COP', 'symbol': r'$', 'name': 'Peso Colombiano (COP)'},
    {'code': 'USD', 'symbol': r'u$s', 'name': 'Dólar Estadounidense (USD)'},
    {'code': 'EUR', 'symbol': r'€', 'name': 'Euro (EUR)'},
    {'code': 'MXN', 'symbol': r'$', 'name': 'Peso Mexicano (MXN)'},
    {'code': 'ARS', 'symbol': r'$', 'name': 'Peso Argentino (ARS)'},
    {'code': 'CLP', 'symbol': r'$', 'name': 'Peso Chileno (CLP)'},
  ];

  @override
  void initState() {
    super.initState();
    final taller = context.read<TallerProvider>().taller;

    _nombreController =
        TextEditingController(text: taller?.nombreTaller ?? 'Mi Taller');
    _telefonoController = TextEditingController(text: taller?.telefono ?? '');
    _direccionController = TextEditingController(text: taller?.direccion ?? '');
    _ciudadController = TextEditingController(text: taller?.ciudad ?? '');
    _impuestoController = TextEditingController(
        text: (taller?.porcentajeImpuestoDefecto ?? 0.0).toStringAsFixed(1));
    _terminosController =
        TextEditingController(text: taller?.terminosCondicionesFactura ?? '');

    _monedaSeleccionada = taller?.moneda ?? 'COP';
    _logoUrl = taller?.logoUrl;
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    _impuestoController.dispose();
    _terminosController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarYSubirLogo() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 500,
        maxHeight: 500,
        imageQuality: 85,
      );

      if (image == null) return;

      setState(() {
        _subiendoLogo = true;
      });

      // ── Subir a Supabase Storage (SaaS mode) ──
      final user = SupabaseService.isConfigured
          ? SupabaseService.client.auth.currentUser
          : null;
      if (user != null) {
        final bytes = await image.readAsBytes();
        final fileExtension = image.name.split('.').last.toLowerCase();
        final contentType = fileExtension == 'png' ? 'image/png' : 'image/jpeg';
        final fileName =
            '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';
        final filePath = 'logos/$fileName';

        await SupabaseService.client.storage.from('logos').uploadBinary(
              filePath,
              bytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );

        final publicUrl =
            SupabaseService.client.storage.from('logos').getPublicUrl(filePath);

        setState(() {
          _logoUrl = publicUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logotipo subido exitosamente'),
            backgroundColor: AppTheme.success,
          ),
        );
      } else {
        // Modo demo/offline
        setState(() {
          _logoUrl =
              'https://images.unsplash.com/photo-1599819811279-d5ad9cccf838?q=80&w=200&auto=format&fit=crop';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logotipo simulado cargado (Modo local)'),
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error cargando logo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al subir logotipo: $e'),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      setState(() {
        _subiendoLogo = false;
      });
    }
  }

  Future<void> _exportarRespaldo() async {
    setState(() => _exportando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final taller = context.read<TallerProvider>().taller;
      final resumen = await RespaldoService.exportar(taller: taller);
      messenger.showSnackBar(SnackBar(
        content: Text(
            'Respaldo listo: ${resumen['ordenes']} ordenes, ${resumen['clientes']} clientes, ${resumen['items']} items.'),
        backgroundColor: AppTheme.success,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('No se pudo generar el respaldo: $e'),
        backgroundColor: AppTheme.error,
      ));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  Future<void> _exportarCsv() async {
    setState(() => _exportando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final total = await RespaldoService.exportarCsvOrdenes();
      messenger.showSnackBar(SnackBar(
        content: Text('$total ordenes exportadas a CSV.'),
        backgroundColor: AppTheme.success,
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('No se pudo exportar: $e'),
        backgroundColor: AppTheme.error,
      ));
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  /// Pide el PIN para volver a modo administrador.
  Future<void> _pedirPinYVolver() async {
    final pinCtrl = TextEditingController();
    final sesion = context.read<SesionLocalProvider>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Volver a modo administrador'),
        content: TextField(
          controller: pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'PIN'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Entrar')),
        ],
      ),
    );

    if (ok != true) return;
    final correcto = await sesion.volverAModoAdministrador(pin: pinCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(correcto ? 'Modo administrador activo' : 'PIN incorrecto'),
      backgroundColor: correcto ? AppTheme.success : AppTheme.error,
    ));
  }

  Future<void> _definirPin() async {
    final pinCtrl = TextEditingController();
    final sesion = context.read<SesionLocalProvider>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('PIN del administrador'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Se pedira para volver del modo mecanico. Dejalo vacio para quitarlo.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PIN'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );

    if (ok != true) return;
    await sesion.definirPin(pinCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN actualizado')),
    );
  }

  Widget _buildModoTrabajo() {
    final sesion = context.watch<SesionLocalProvider>();
    final esAdmin = sesion.esAdministrador;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(esAdmin ? Icons.shield_rounded : Icons.build_rounded,
                color: esAdmin ? AppTheme.primaryLight : AppTheme.warning,
                size: 20),
            const SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Text(
                sesion.rol.label,
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Text(
          esAdmin
              ? 'Ves todo: precios de costo, ganancias y caja. Pasa a modo mecanico antes de prestar el telefono.'
              : 'El telefono esta en modo mecanico: se ocultan costos, ganancias y contabilidad.',
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: AppTheme.spacingMd),
        if (esAdmin) ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.build_rounded, size: 18),
            label: const Text('Pasar a modo mecanico'),
            onPressed: () async {
              await context.read<SesionLocalProvider>().activarModoMecanico();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Modo mecanico activo')),
              );
            },
          ),
          const SizedBox(height: AppTheme.spacingSm),
          TextButton.icon(
            icon: const Icon(Icons.password_rounded, size: 18),
            label: Text(sesion.tienePin ? 'Cambiar PIN' : 'Poner un PIN'),
            onPressed: _definirPin,
          ),
        ] else
          ElevatedButton.icon(
            icon:
                const Icon(Icons.shield_rounded, size: 18, color: Colors.white),
            label: const Text('Volver a administrador'),
            onPressed: _pedirPinYVolver,
          ),
        const SizedBox(height: AppTheme.spacingSm),
        const Text(
          'Nota: es un bloqueo de la pantalla, pensado para el dia a dia del taller. No sustituye tener cuentas separadas.',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 11),
        ),
      ],
    );
  }

  Future<void> _guardarAjustes() async {
    if (!_formKey.currentState!.validate()) return;

    final tallerProvider = context.read<TallerProvider>();

    final tallerActual = tallerProvider.taller;
    if (tallerActual == null) return;

    final impuesto = double.tryParse(_impuestoController.text) ?? 0.0;

    final tallerActualizado = tallerActual.copyWith(
      nombreTaller: _nombreController.text.trim(),
      telefono: _telefonoController.text.trim(),
      direccion: _direccionController.text.trim(),
      ciudad: _ciudadController.text.trim(),
      moneda: _monedaSeleccionada,
      porcentajeImpuestoDefecto: impuesto,
      terminosCondicionesFactura: _terminosController.text.trim(),
      logoUrl: _logoUrl,
    );

    final exito = await tallerProvider.actualizarTaller(tallerActualizado);

    if (exito) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ajustes guardados correctamente'),
          backgroundColor: AppTheme.success,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar ajustes: ${tallerProvider.error}'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tallerProvider = context.watch<TallerProvider>();
    final authProvider = context.watch<AuthProvider>();

    if (tallerProvider.isLoading && tallerProvider.taller == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Ajustes del Taller'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.error),
            tooltip: 'Cerrar Sesión',
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cerrar Sesión'),
                  content: const Text(
                      '¿Está seguro de que desea salir? los datos no guardados se perderán.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        Navigator.pop(context);
                        tallerProvider.setTaller(null);
                        await authProvider.signOut();
                      },
                      child: const Text('Salir'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── SECCIÓN IDENTIDAD VISUAL (LOGO) ──
                _buildSeccionCard(
                  titulo: 'Identidad Visual',
                  icono: Icons.photo_library_outlined,
                  child: Column(
                    children: [
                      Center(
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceLight,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusLg),
                                border: Border.all(
                                    color: AppTheme.surfaceBorder, width: 1.5),
                              ),
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusLg),
                                child: _logoUrl != null && _logoUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: _logoUrl!,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) =>
                                            const Center(
                                          child: CircularProgressIndicator(),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                          Icons.storefront_rounded,
                                          size: 50,
                                          color: AppTheme.textTertiary,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.storefront_rounded,
                                        size: 50,
                                        color: AppTheme.textTertiary,
                                      ),
                              ),
                            ),
                            if (_subiendoLogo)
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  borderRadius:
                                      BorderRadius.circular(AppTheme.radiusLg),
                                ),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                      color: AppTheme.primaryLight),
                                ),
                              ),
                            Positioned(
                              bottom: -4,
                              right: -4,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.surface, width: 2),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 18),
                                  onPressed: _subiendoLogo
                                      ? null
                                      : _seleccionarYSubirLogo,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade().scale(duration: 350.ms),
                      const SizedBox(height: AppTheme.spacingMd),
                      Text(
                        'Carga el logo del taller para personalizar las facturas PDF y la identidad interna.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacingMd),

                // ── SECCIÓN DATOS DEL TALLER ──
                _buildSeccionCard(
                  titulo: 'Datos del Negocio',
                  icono: Icons.storefront_outlined,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _nombreController,
                        decoration: const InputDecoration(
                          labelText: 'Nombre del Taller',
                          prefixIcon: Icon(Icons.business_rounded),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Este campo es obligatorio'
                                : null,
                      ),
                      const SizedBox(height: AppTheme.spacingSm + 4),
                      TextFormField(
                        controller: _telefonoController,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          prefixIcon: Icon(Icons.phone_rounded),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: AppTheme.spacingSm + 4),
                      TextFormField(
                        controller: _direccionController,
                        decoration: const InputDecoration(
                          labelText: 'Dirección',
                          prefixIcon: Icon(Icons.location_on_rounded),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingSm + 4),
                      TextFormField(
                        controller: _ciudadController,
                        decoration: const InputDecoration(
                          labelText: 'Ciudad / País',
                          prefixIcon: Icon(Icons.location_city_rounded),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacingMd),

                // ── SECCIÓN FACTURACIÓN ──
                _buildSeccionCard(
                  titulo: 'Preferencias de Factura',
                  icono: Icons.receipt_long_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _monedaSeleccionada,
                        decoration: const InputDecoration(
                          labelText: 'Moneda Local',
                          prefixIcon: Icon(Icons.monetization_on_rounded),
                        ),
                        items: _monedas.map((m) {
                          return DropdownMenuItem<String>(
                            value: m['code'],
                            child: Text(m['name']!),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _monedaSeleccionada = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingSm + 4),
                      TextFormField(
                        controller: _impuestoController,
                        decoration: const InputDecoration(
                          labelText: 'Impuesto por Defecto (Porcentaje %)',
                          prefixIcon: Icon(Icons.percent_rounded),
                          hintText: 'Ej. 19.0 para IVA del 19%',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return null;
                          }
                          final doubleVal = double.tryParse(value);
                          if (doubleVal == null || doubleVal < 0) {
                            return 'Debe ser un número positivo válido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppTheme.spacingSm + 4),
                      TextFormField(
                        controller: _terminosController,
                        decoration: const InputDecoration(
                          labelText: 'Términos y Condiciones (Pie de Factura)',
                          prefixIcon: Icon(Icons.gavel_rounded),
                          hintText:
                              'Ej: Garantía de 30 días en mano de obra...',
                        ),
                        maxLines: 3,
                        keyboardType: TextInputType.multiline,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacingMd),

                // ── SECCIÓN CONTABILIDAD Y CAJA ──
                if (context.watch<SesionLocalProvider>().puedeVerFinanzas)
                  _buildSeccionCard(
                    titulo: 'Finanzas & Flujo de Caja',
                    icono: Icons.account_balance_wallet_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Controla el dinero de tu negocio de forma automática. Revisa ingresos, gastos y ganancia neta en tiempo real.',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.analytics_rounded,
                              color: Colors.white),
                          label: const Text('Abrir Módulo Contable'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.surfaceLight,
                            foregroundColor: AppTheme.primaryLight,
                            side:
                                const BorderSide(color: AppTheme.surfaceBorder),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusMd),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ContabilidadScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: AppTheme.spacingMd),

                _buildSeccionCard(
                  titulo: 'Próximos Mantenimientos',
                  icono: Icons.event_repeat_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Las motos que llevan tiempo sin volver, con el botón para escribirle al dueño por WhatsApp.',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.notifications_active_rounded,
                            size: 18),
                        label: const Text('Ver a quién llamar'),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const RecordatoriosScreen()),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacingMd),

                if (!kIsWeb)
                  _buildSeccionCard(
                    titulo: 'Rescatar datos del teléfono',
                    icono: Icons.cloud_sync_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'El detalle de repuestos y los abonos de las órdenes '
                          'se guardaron en este teléfono pero no llegaron a la '
                          'nube. Aquí puedes comprobarlo y subirlos.',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: AppTheme.spacingMd),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.cloud_upload_outlined,
                              size: 18),
                          label: const Text('Comprobar y subir pendientes'),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RescateDatosScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (!kIsWeb) const SizedBox(height: AppTheme.spacingMd),

                _buildSeccionCard(
                  titulo: 'Copia de Seguridad',
                  icono: Icons.cloud_download_outlined,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Descarga todos tus datos: clientes, motos, órdenes, inventario y caja. Guárdalo donde quieras; no dependes de nadie para conservarlos.',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: AppTheme.spacingMd),
                      OutlinedButton.icon(
                        icon: _exportando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save_alt_rounded, size: 18),
                        label: const Text('Exportar respaldo completo'),
                        onPressed: _exportando ? null : _exportarRespaldo,
                      ),
                      const SizedBox(height: AppTheme.spacingSm),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.table_chart_outlined, size: 18),
                        label: const Text('Órdenes en Excel (CSV)'),
                        onPressed: _exportando ? null : _exportarCsv,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spacingMd),

                _buildSeccionCard(
                  titulo: 'Modo de Trabajo',
                  icono: Icons.badge_outlined,
                  child: _buildModoTrabajo(),
                ),

                const SizedBox(height: AppTheme.spacingLg),

                // ── BOTÓN GUARDAR AJUSTES ──
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacingMd),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  onPressed: tallerProvider.isLoading ? null : _guardarAjustes,
                  child: tallerProvider.isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text(
                          'Guardar Configuración del Taller',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ).animate().shimmer(delay: 500.ms, duration: 1.seconds),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSeccionCard({
    required String titulo,
    required IconData icono,
    required Widget child,
  }) {
    return Container(
      decoration: AppTheme.elevatedCardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icono, color: AppTheme.primaryLight, size: 22),
                const SizedBox(width: AppTheme.spacingSm),
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const Divider(color: AppTheme.surfaceBorder, height: 24),
            child,
          ],
        ),
      ),
    );
  }
}
