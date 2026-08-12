import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../data/models/cliente.dart';
import '../../data/models/vehiculo.dart';
import '../../data/providers/ordenes_provider.dart';

/// Pantalla premium de Check-in de motocicleta con inspeccion fisica.
class CrearOrdenScreen extends StatefulWidget {
  const CrearOrdenScreen({super.key});
  @override
  State<CrearOrdenScreen> createState() => _CrearOrdenScreenState();
}

class _CrearOrdenScreenState extends State<CrearOrdenScreen> {
  final _formKey = GlobalKey<FormState>();
  final _picker   = ImagePicker();

  bool _esNuevoCliente = true;
  bool _esCotizacion = false;
  Cliente?  _clienteSeleccionado;
  Vehiculo? _vehiculoSeleccionado;
  List<Vehiculo> _vehiculosDelCliente = [];

  // Fotos de inspección fisica (max 4)
  final List<XFile> _fotos = [];
  bool _subiendoFotos = false;

  // Controllers - cliente nuevo
  final _nombreCtrl    = TextEditingController();
  final _apellidoCtrl  = TextEditingController();
  final _telefonoCtrl  = TextEditingController();
  final _documentoCtrl = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _direccionCtrl = TextEditingController();
  final _daneCtrl      = TextEditingController(text: '68001');

  TipoDocumento _tipoDocumento = TipoDocumento.cc;
  RegimenFiscal _regimenFiscal = RegimenFiscal.noResponsable;
  String? _dvStr;

  // Controllers - vehiculo nuevo
  final _placaCtrl  = TextEditingController();
  final _marcaCtrl  = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl   = TextEditingController();

  // Controllers - orden
  final _kilometrajeCtrl = TextEditingController();
  final _problemaCtrl    = TextEditingController();
  final _mecanicoCtrl    = TextEditingController();

  final _tipoServicioCustomCtrl = TextEditingController();

  String _tipoServicio = TiposServicio.preventivo;

  @override
  void initState() {
    super.initState();
    _documentoCtrl.addListener(_onDocumentoChanged);
  }

  void _onDocumentoChanged() {
    if (_tipoDocumento == TipoDocumento.nit) {
      setState(() {
        _dvStr = Cliente.calcularDV(_documentoCtrl.text);
      });
    }
  }

  @override
  void dispose() {
    _documentoCtrl.removeListener(_onDocumentoChanged);
    _nombreCtrl.dispose();    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();  _documentoCtrl.dispose();
    _emailCtrl.dispose();     _direccionCtrl.dispose();
    _daneCtrl.dispose();
    _placaCtrl.dispose();     _marcaCtrl.dispose();
    _modeloCtrl.dispose();    _anioCtrl.dispose();
    _kilometrajeCtrl.dispose(); _problemaCtrl.dispose();
    _mecanicoCtrl.dispose();
    _tipoServicioCustomCtrl.dispose();
    super.dispose();
  }

  Future<void> _actualizarVehiculos(String clienteId) async {
    final vehs = await context.read<OrdenesProvider>().obtenerVehiculosDeCliente(clienteId);
    setState(() {
      _vehiculosDelCliente = vehs;
      _vehiculoSeleccionado = vehs.isNotEmpty ? vehs.first : null;
      if (_vehiculoSeleccionado != null) {
        _kilometrajeCtrl.text = _vehiculoSeleccionado!.kilometrajeActual.toString();
      } else { _kilometrajeCtrl.clear(); }
    });
  }

  Future<void> _agregarFoto() async {
    if (_fotos.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Máximo 4 fotos por inspección')),
      );
      return;
    }
    final source = await _mostrarOpcionFoto();
    if (source == null) return;
    try {
      final XFile? file = await _picker.pickImage(
        source: source, maxWidth: 1280, maxHeight: 960, imageQuality: 80,
      );
      if (file != null) setState(() => _fotos.add(file));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar foto: $e')),
      );
      }
    }
  }

  Future<ImageSource?> _mostrarOpcionFoto() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(
              color: AppTheme.textTertiary, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            const Text('Agregar foto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(child: _SourceButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Cámara',
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                )),
                const SizedBox(width: 12),
                Expanded(child: _SourceButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Galería',
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                )),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarOrden() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger  = ScaffoldMessenger.of(context);
    final navigator  = Navigator.of(context);
    final provider   = context.read<OrdenesProvider>();
    HapticFeedback.mediumImpact();
    setState(() => _subiendoFotos = true);

    try {
      if (_esNuevoCliente) {
        await provider.crearOrdenRapida(
          nombreCliente:         _nombreCtrl.text.trim(),
          apellidoCliente:       _apellidoCtrl.text.trim(),
          telefonoCliente:       _telefonoCtrl.text.trim(),
          numeroDocumentoCliente: _documentoCtrl.text.trim(),
          tipoDocumento:          _tipoDocumento,
          digitoVerificacion:     _dvStr,
          regimenFiscal:          _regimenFiscal,
          codigoMunicipioDane:    _daneCtrl.text.trim().isEmpty ? '68001' : _daneCtrl.text.trim(),
          emailCliente:          _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
          direccionCliente:      _direccionCtrl.text.trim().isEmpty ? null : _direccionCtrl.text.trim(),
          placaPatente:          _placaCtrl.text.trim().toUpperCase(),
          marca:                 _marcaCtrl.text.trim(),
          modelo:                _modeloCtrl.text.trim(),
          anio:                  int.tryParse(_anioCtrl.text) ?? DateTime.now().year,
          kilometrajeIngreso:    int.tryParse(_kilometrajeCtrl.text) ?? 0,
          descripcionProblema:   _problemaCtrl.text.trim(),
          mecanicoAsignado:      _mecanicoCtrl.text.trim(),
          tipoServicio:          _tipoServicio == TiposServicio.otro ? _tipoServicioCustomCtrl.text.trim() : _tipoServicio,
          fotosEstado:           _fotos.map((f) => f.path).toList(),
          esCotizacion:          _esCotizacion,
        );
      } else {
        if (_clienteSeleccionado == null || _vehiculoSeleccionado == null) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Seleccione cliente y vehículo')),
          );
          setState(() => _subiendoFotos = false);
          return;
        }
        await provider.crearOrdenClienteExistente(
          clienteId:           _clienteSeleccionado!.id,
          vehiculoId:          _vehiculoSeleccionado!.id,
          kilometrajeIngreso:  int.tryParse(_kilometrajeCtrl.text) ?? 0,
          descripcionProblema: _problemaCtrl.text.trim(),
          mecanicoAsignado:    _mecanicoCtrl.text.trim(),
          tipoServicio:        _tipoServicio == TiposServicio.otro ? _tipoServicioCustomCtrl.text.trim() : _tipoServicio,
          fotosEstado:         _fotos.map((f) => f.path).toList(),
          esCotizacion:        _esCotizacion,
        );
      }

      // Éxito: mostrar confirmación y volver
      setState(() => _subiendoFotos = false);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF065F46),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: AppTheme.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _esCotizacion
                      ? 'Cotización creada con éxito'
                      : 'Orden creada con éxito${_fotos.isNotEmpty ? " con ${_fotos.length} foto(s)" : ""}',
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      navigator.pop();
    } catch (e) {
      // Error: mostrar mensaje al usuario y mantenerlo en la pantalla
      setState(() => _subiendoFotos = false);
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF7F1D1D),
          duration: const Duration(seconds: 5),
          content: Row(
            children: [
              const Icon(Icons.error_rounded, color: AppTheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Error al guardar: ${e.toString().replaceAll('Exception: ', '')}',
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdenesProvider>();
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text(_esCotizacion ? 'Nueva Cotización' : 'Check-in de Motocicleta')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            // ── Toggle nuevo/existente ────────────────────────
            _buildClienteToggle(),
            const SizedBox(height: AppTheme.spacingLg),
            _esNuevoCliente ? _buildNuevoClienteForm() : _buildClienteExistenteForm(provider),
            const SizedBox(height: AppTheme.spacingLg),
            if (_esNuevoCliente) _buildNuevoVehiculoForm() else _buildVehiculoExistenteForm(),
            const SizedBox(height: AppTheme.spacingLg),
            _buildDetalleOrden(),
            const SizedBox(height: AppTheme.spacingLg),
            // ── Seccion FOTOS DE INSPECCION ───────────────────
            _buildInspeccionFisica(),
            const SizedBox(height: AppTheme.spacingLg),
            // ── Botón guardar ─────────────────────────────────
            _buildSaveButton(),
            const SizedBox(height: AppTheme.spacingXl),
          ],
        ),
      ),
    );
  }

  Widget _buildClienteToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          _ToggleChip(label: 'Nuevo Cliente',    selected: _esNuevoCliente,   onTap: () => setState(() { _esNuevoCliente = true; })),
          _ToggleChip(label: 'Cliente Existente', selected: !_esNuevoCliente, onTap: () {
            final provider = context.read<OrdenesProvider>();
            setState(() {
              _esNuevoCliente = false;
              if (provider.clientes.isNotEmpty) {
                _clienteSeleccionado = provider.clientes.first;
                _actualizarVehiculos(_clienteSeleccionado!.id);
              }
            });
          }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryLight, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(
          color: AppTheme.primaryLight, fontSize: 12,
          fontWeight: FontWeight.w800, letterSpacing: 1.2,
        )),
      ],
    );
  }

  Widget _buildNuevoClienteForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionHeader('INFORMACIÓN DEL CLIENTE', Icons.person_rounded),
      const SizedBox(height: AppTheme.spacingSm),
      Container(padding: const EdgeInsets.all(AppTheme.spacingMd), decoration: AppTheme.cardDecoration, child: Column(children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre'), validator: _req),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(controller: _apellidoCtrl, decoration: const InputDecoration(labelText: 'Apellido'), validator: _req),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: DropdownButtonFormField<TipoDocumento>(
                initialValue: _tipoDocumento,
                dropdownColor: AppTheme.surface,
                decoration: const InputDecoration(labelText: 'Tipo Doc.'),
                items: TipoDocumento.values.map((t) => DropdownMenuItem(value: t, child: Text(t.value))).toList(),
                onChanged: (v) {
                  if (v != null) {
                    setState(() {
                      _tipoDocumento = v;
                      if (v == TipoDocumento.nit) {
                        _dvStr = Cliente.calcularDV(_documentoCtrl.text);
                      } else {
                        _dvStr = null;
                      }
                    });
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _documentoCtrl,
                decoration: InputDecoration(
                  labelText: 'Nº Documento',
                  suffixIcon: _tipoDocumento == TipoDocumento.nit && _dvStr != null
                      ? Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'DV: $_dvStr',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryLight, fontSize: 12),
                          ),
                        )
                      : null,
                ),
                keyboardType: TextInputType.number,
                validator: _req,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DropdownButtonFormField<RegimenFiscal>(
                initialValue: _regimenFiscal,
                dropdownColor: AppTheme.surface,
                decoration: const InputDecoration(labelText: 'Régimen Fiscal (DIAN)'),
                items: RegimenFiscal.values.map((r) => DropdownMenuItem(value: r, child: Text(r.label, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (v) { if (v != null) setState(() => _regimenFiscal = v); },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _daneCtrl,
                decoration: const InputDecoration(labelText: 'Cód. DANE (Ciudad)'),
                keyboardType: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _telefonoCtrl,  decoration: const InputDecoration(labelText: 'Teléfono'), keyboardType: TextInputType.phone, validator: _req),
        const SizedBox(height: 12),
        TextFormField(controller: _emailCtrl,     decoration: const InputDecoration(labelText: 'Correo Electrónico (Opcional)'), keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 12),
        TextFormField(controller: _direccionCtrl, decoration: const InputDecoration(labelText: 'Dirección (Opcional)', prefixIcon: Icon(Icons.location_on_outlined, color: AppTheme.textTertiary)), textCapitalization: TextCapitalization.words),
      ])),
    ]);
  }

  Widget _buildClienteExistenteForm(OrdenesProvider provider) {
    if (provider.clientes.isEmpty) {
      return Container(padding: const EdgeInsets.all(AppTheme.spacingMd), decoration: AppTheme.cardDecoration,
        child: const Center(child: Text('No hay clientes registrados.')));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionHeader('CLIENTE EXISTENTE', Icons.manage_accounts_rounded),
      const SizedBox(height: AppTheme.spacingSm),
      Container(padding: const EdgeInsets.all(AppTheme.spacingMd), decoration: AppTheme.cardDecoration,
        child: DropdownButtonFormField<Cliente>(
          initialValue: _clienteSeleccionado, dropdownColor: AppTheme.surface,
          decoration: const InputDecoration(labelText: 'Cliente'),
          items: provider.clientes.map((c) => DropdownMenuItem(value: c, child: Text('${c.nombreCompleto} (${c.numeroDocumento})'))).toList(),
          onChanged: (v) { if (v != null) { setState(() { _clienteSeleccionado = v; _actualizarVehiculos(v.id); }); } },
        )),
    ]);
  }

  Widget _buildNuevoVehiculoForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionHeader('INFORMACIÓN DE LA MOTO', Icons.two_wheeler_rounded),
      const SizedBox(height: AppTheme.spacingSm),
      Container(padding: const EdgeInsets.all(AppTheme.spacingMd), decoration: AppTheme.cardDecoration, child: Column(children: [
        TextFormField(controller: _placaCtrl, decoration: const InputDecoration(labelText: 'Placa / Patente'), textCapitalization: TextCapitalization.characters, validator: _req),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: TextFormField(controller: _marcaCtrl,  decoration: const InputDecoration(labelText: 'Marca'), validator: _req)),
          const SizedBox(width: 12),
          Expanded(child: TextFormField(controller: _modeloCtrl, decoration: const InputDecoration(labelText: 'Modelo'), validator: _req)),
        ]),
        const SizedBox(height: 12),
        TextFormField(controller: _anioCtrl, decoration: const InputDecoration(labelText: 'Año'),
          keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: (v) { if (v == null || v.isEmpty) return 'Requerido'; final val = int.tryParse(v); if (val == null || val < 1970 || val > DateTime.now().year + 1) return 'Año inválido'; return null; }),
      ])),
    ]);
  }

  Widget _buildVehiculoExistenteForm() {
    if (_clienteSeleccionado == null) return const SizedBox.shrink();
    if (_vehiculosDelCliente.isEmpty) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionHeader('MOTO DEL CLIENTE', Icons.two_wheeler_rounded),
        const SizedBox(height: AppTheme.spacingSm),
        Container(padding: const EdgeInsets.all(AppTheme.spacingMd), decoration: AppTheme.cardDecoration,
          child: const Text('Sin motos registradas. Use "Nuevo Cliente" para agregar la primera.', style: TextStyle(color: AppTheme.textTertiary, fontSize: 12), textAlign: TextAlign.center)),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionHeader('SELECCIONAR VEHÍCULO', Icons.two_wheeler_rounded),
      const SizedBox(height: AppTheme.spacingSm),
      Container(padding: const EdgeInsets.all(AppTheme.spacingMd), decoration: AppTheme.cardDecoration,
        child: DropdownButtonFormField<Vehiculo>(
          initialValue: _vehiculoSeleccionado, dropdownColor: AppTheme.surface,
          decoration: const InputDecoration(labelText: 'Motocicleta'),
          items: _vehiculosDelCliente.map((v) => DropdownMenuItem(value: v, child: Text('${v.marca} ${v.modelo} [${v.placaPatente}]'))).toList(),
          onChanged: (v) { if (v != null) { setState(() { _vehiculoSeleccionado = v; _kilometrajeCtrl.text = v.kilometrajeActual.toString(); }); } },
        )),
    ]);
  }

  Widget _buildDetalleOrden() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionHeader('DETALLES DE INGRESO', Icons.build_rounded),
      const SizedBox(height: AppTheme.spacingSm),
      Container(padding: const EdgeInsets.all(AppTheme.spacingMd), decoration: AppTheme.cardDecoration, child: Column(children: [
        DropdownButtonFormField<String>(
          initialValue: _tipoServicio, dropdownColor: AppTheme.surface,
          decoration: const InputDecoration(labelText: 'Tipo de Servicio'),
          items: TiposServicio.valores.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
          onChanged: (v) { if (v != null) setState(() => _tipoServicio = v); },
        ),
        if (_tipoServicio == TiposServicio.otro) ...[
          const SizedBox(height: 12),
          TextFormField(
            controller: _tipoServicioCustomCtrl,
            decoration: const InputDecoration(labelText: 'Escribir servicio personalizado', prefixIcon: Icon(Icons.edit, color: AppTheme.textTertiary)),
            validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
          ),
        ],
        const SizedBox(height: 12),
        TextFormField(controller: _kilometrajeCtrl,
          decoration: const InputDecoration(labelText: 'Kilometraje de Ingreso', prefixIcon: Icon(Icons.speed, color: AppTheme.textTertiary)),
          keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: _req),
        const SizedBox(height: 12),
        TextFormField(controller: _mecanicoCtrl,
          decoration: const InputDecoration(labelText: 'Mecánico Responsable', prefixIcon: Icon(Icons.engineering_rounded, color: AppTheme.textTertiary)),
          validator: _req),
        const SizedBox(height: 12),
        TextFormField(controller: _problemaCtrl,
          decoration: const InputDecoration(labelText: 'Problema que reporta el cliente', hintText: 'Ej. Ruidos al frenar, cambio de aceite...', alignLabelWithHint: true),
          maxLines: 3, validator: _req),
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Registrar como Cotización', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          subtitle: const Text('No descontará stock de repuestos ni registrará flujos de caja contables.', style: TextStyle(fontSize: 12, color: AppTheme.textTertiary)),
          value: _esCotizacion,
          onChanged: (val) => setState(() => _esCotizacion = val),
          activeThumbColor: AppTheme.primaryLight,
          contentPadding: EdgeInsets.zero,
        ),
      ])),
    ]);
  }

  // ── Sección premium de Inspección Física ──────────────────────────────────
  Widget _buildInspeccionFisica() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('INSPECCIÓN FÍSICA / ESTADO DEL VEHÍCULO', Icons.camera_alt_rounded),
        const SizedBox(height: 6),
        const Text(
          'Documenta el estado visual de la moto al ingreso (max. 4 fotos).',
          style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: AppTheme.cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Carrusel de slots
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 4,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    if (index < _fotos.length) {
                      return _FotoSlot(
                        foto: _fotos[index],
                        onRemove: () => setState(() => _fotos.removeAt(index)),
                      );
                    }
                    return _EmptySlot(
                      onTap: _fotos.length < 4 ? _agregarFoto : null,
                      isActive: index == _fotos.length,
                    );
                  },
                ),
              ),
              if (_fotos.isNotEmpty) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      '${_fotos.length}/4 foto${_fotos.length > 1 ? "s" : ""} seleccionada${_fotos.length > 1 ? "s" : ""}',
                      style: const TextStyle(color: AppTheme.success, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => setState(() => _fotos.clear()),
                      icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppTheme.error),
                      label: const Text('Limpiar', style: TextStyle(color: AppTheme.error, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.05);
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF6366F1)]),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: ElevatedButton(
        onPressed: _subiendoFotos ? null : _guardarOrden,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        ),
        child: _subiendoFotos
            ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                SizedBox(width: 10),
                Text('Guardando y subiendo fotos...'),
              ])
            : const Text('REGISTRAR CHECK-IN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
      ),
    );
  }

  String? _req(String? v) => v == null || v.trim().isEmpty ? 'Requerido' : null;
}

// ── Slot con foto ──────────────────────────────────────────────────────────────
class _FotoSlot extends StatelessWidget {
  final XFile foto;
  final VoidCallback onRemove;
  const _FotoSlot({required this.foto, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Image.network(
            foto.path,
            width: 100, height: 110, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 100, height: 110,
              decoration: BoxDecoration(color: AppTheme.surfaceLight, borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
              child: const Icon(Icons.image_rounded, color: AppTheme.textTertiary, size: 36),
            ),
          ),
        ),
        Positioned(
          top: 4, right: 4,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24, height: 24,
              decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
            ),
          ),
        ),
      ],
    ).animate().scale(duration: 200.ms, curve: Curves.easeOut);
  }
}

// ── Slot vacío ────────────────────────────────────────────────────────────────
class _EmptySlot extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isActive;
  const _EmptySlot({this.onTap, required this.isActive});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 100, height: 110,
        decoration: BoxDecoration(
          color: isActive && onTap != null
              ? AppTheme.primarySurface
              : AppTheme.surfaceLight,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: isActive && onTap != null
                ? AppTheme.primaryLight
                : AppTheme.surfaceBorder,
            width: isActive && onTap != null ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_a_photo_rounded,
              color: isActive && onTap != null
                  ? AppTheme.primaryLight
                  : AppTheme.textTertiary,
              size: 28,
            ),
            const SizedBox(height: 6),
            Text(
              isActive && onTap != null ? 'Añadir' : '',
              style: TextStyle(
                color: isActive && onTap != null
                    ? AppTheme.primaryLight
                    : AppTheme.textTertiary,
                fontSize: 11, fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Botón de fuente de imagen ─────────────────────────────────────────────────
class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SourceButton({required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: AppTheme.primarySurface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.primaryLight.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryLight, size: 30),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Toggle chip ───────────────────────────────────────────────────────────────
class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          ),
          child: Center(
            child: Text(label, style: TextStyle(
              color: selected ? Colors.white : AppTheme.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13,
            )),
          ),
        ),
      ),
    );
  }
}
