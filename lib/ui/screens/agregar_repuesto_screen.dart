import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/repuesto.dart';
import '../../data/providers/inventario_provider.dart';

/// Formulario reutilizable para crear o editar un repuesto del inventario.
///
/// - [repuestoAEditar] == null  →  modo CREAR (insert)
/// - [repuestoAEditar] != null  →  modo EDITAR (upsert con el mismo id)
class AgregarRepuestoScreen extends StatefulWidget {
  final String? codigoPrefill;
  final String? nombrePrefill;
  final Repuesto? repuestoAEditar;

  const AgregarRepuestoScreen({
    super.key,
    this.codigoPrefill,
    this.nombrePrefill,
    this.repuestoAEditar,
  });

  @override
  State<AgregarRepuestoScreen> createState() => _AgregarRepuestoScreenState();
}

class _AgregarRepuestoScreenState extends State<AgregarRepuestoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl     = TextEditingController();
  final _nombreCtrl     = TextEditingController();
  final _descCtrl       = TextEditingController();
  final _marcaCtrl      = TextEditingController();
  final _numeroParteCtrl = TextEditingController();
  final _stockCtrl      = TextEditingController(text: '0');
  final _stockMinCtrl   = TextEditingController(text: '5');
  final _costoCtrl      = TextEditingController(text: '0');
  final _ventaCtrl      = TextEditingController(text: '0');
  CategoriaRepuesto _categoria = CategoriaRepuesto.otros;
  XFile? _foto;
  bool _saving = false;

  bool get _esEdicion => widget.repuestoAEditar != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      final r = widget.repuestoAEditar!;
      _codigoCtrl.text      = r.codigoInterno;
      _nombreCtrl.text      = r.nombre;
      _descCtrl.text        = r.descripcion ?? '';
      _marcaCtrl.text       = r.marcaRepuesto ?? '';
      _numeroParteCtrl.text = r.numeroParte ?? '';
      _stockCtrl.text       = r.stockActual.toString();
      _stockMinCtrl.text    = r.stockMinimo.toString();
      _costoCtrl.text       = r.precioCosto.toStringAsFixed(2);
      _ventaCtrl.text       = r.precioVenta.toStringAsFixed(2);
      _categoria            = r.categoria;
    } else {
      if (widget.codigoPrefill != null) _codigoCtrl.text = widget.codigoPrefill!;
      if (widget.nombrePrefill != null) _nombreCtrl.text = widget.nombrePrefill!;
    }
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();     _nombreCtrl.dispose();
    _descCtrl.dispose();       _marcaCtrl.dispose();
    _numeroParteCtrl.dispose();_stockCtrl.dispose();
    _stockMinCtrl.dispose();   _costoCtrl.dispose();
    _ventaCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 80,
    );
    if (image != null) setState(() => _foto = image);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final provider = context.read<InventarioProvider>();
    try {
      if (_esEdicion) {
        // Modo EDICIÓN: upsert basado en el id existente
        final updated = widget.repuestoAEditar!.copyWith(
          codigoInterno: _codigoCtrl.text.trim(),
          nombre:        _nombreCtrl.text.trim(),
          descripcion:   _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          marcaRepuesto: _marcaCtrl.text.trim().isEmpty ? null : _marcaCtrl.text.trim(),
          numeroParte:   _numeroParteCtrl.text.trim().isEmpty ? null : _numeroParteCtrl.text.trim(),
          categoria:     _categoria,
          stockActual:   int.tryParse(_stockCtrl.text) ?? widget.repuestoAEditar!.stockActual,
          stockMinimo:   int.tryParse(_stockMinCtrl.text) ?? widget.repuestoAEditar!.stockMinimo,
          precioCosto:   double.tryParse(_costoCtrl.text) ?? widget.repuestoAEditar!.precioCosto,
          precioVenta:   double.tryParse(_ventaCtrl.text) ?? widget.repuestoAEditar!.precioVenta,
        );
        await provider.actualizarRepuesto(updated);
      } else {
        // Modo CREAR: nuevo registro
        await provider.crearRepuestoConFoto(
          codigoInterno: _codigoCtrl.text.trim(),
          nombre:        _nombreCtrl.text.trim(),
          descripcion:   _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
          categoria:     _categoria,
          stockActual:   int.tryParse(_stockCtrl.text) ?? 0,
          stockMinimo:   int.tryParse(_stockMinCtrl.text) ?? 5,
          precioCosto:   double.tryParse(_costoCtrl.text) ?? 0,
          precioVenta:   double.tryParse(_ventaCtrl.text) ?? 0,
          foto:          _foto,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Repuesto' : 'Nuevo Repuesto'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryLight),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _save,
              icon: Icon(
                _esEdicion ? Icons.save_rounded : Icons.add_circle_rounded,
                size: 18,
                color: AppTheme.primaryLight,
              ),
              label: Text(
                _esEdicion ? 'Guardar' : 'Crear',
                style: const TextStyle(color: AppTheme.primaryLight, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── IDENTIFICACIÓN ────────────────────────────
              _sectionLabel('IDENTIFICACIÓN', Icons.qr_code_rounded),
              const SizedBox(height: 12),
              TextFormField(
                controller: _codigoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Código Interno (SKU) *',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El código es requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre del repuesto *',
                  prefixIcon: Icon(Icons.build_rounded),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _marcaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Marca',
                      prefixIcon: Icon(Icons.branding_watermark_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _numeroParteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'N.° de parte',
                      prefixIcon: Icon(Icons.confirmation_number_rounded),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),

              // ── CATEGORÍA ─────────────────────────────────
              _sectionLabel('CATEGORÍA', Icons.category_rounded),
              const SizedBox(height: 12),
              DropdownButtonFormField<CategoriaRepuesto>(
                initialValue: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: CategoriaRepuesto.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c.icon}  ${c.label}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _categoria = v ?? CategoriaRepuesto.otros),
              ),
              const SizedBox(height: 24),

              // ── STOCK ─────────────────────────────────────
              _sectionLabel('STOCK', Icons.inventory_2_rounded),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Stock actual',
                      prefixIcon: Icon(Icons.numbers_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _stockMinCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Stock mínimo',
                      prefixIcon: Icon(Icons.warning_amber_rounded),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 24),

              // ── PRECIOS ───────────────────────────────────
              _sectionLabel('PRECIOS', Icons.attach_money_rounded),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _costoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    decoration: const InputDecoration(
                      labelText: 'Precio costo',
                      prefixText: '\$ ',
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _ventaCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                    decoration: const InputDecoration(
                      labelText: 'Precio venta',
                      prefixText: '\$ ',
                    ),
                  ),
                ),
              ]),

              // ── FOTO (solo en modo crear) ──────────────────
              if (!_esEdicion) ...[
                const SizedBox(height: 24),
                _sectionLabel('FOTO', Icons.photo_camera_rounded),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.photo_library_rounded),
                  label: Text(_foto == null ? 'Seleccionar foto' : 'Cambiar foto'),
                ),
                if (_foto != null) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.check_circle_rounded, color: AppTheme.success, size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        _foto!.name,
                        style: const TextStyle(color: AppTheme.success, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ]),
                ],
              ],

              const SizedBox(height: 32),

              // ── BOTÓN GUARDAR ─────────────────────────────
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: Icon(
                    _esEdicion ? Icons.save_rounded : Icons.add_circle_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    _esEdicion ? 'GUARDAR CAMBIOS' : 'CREAR REPUESTO',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _esEdicion ? AppTheme.success : AppTheme.primary,
                    disabledBackgroundColor: AppTheme.surfaceLight,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacingXl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primarySurface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppTheme.primaryLight),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}
