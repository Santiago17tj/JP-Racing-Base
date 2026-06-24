import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/constants/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/inventario_provider.dart';

class AgregarRepuestoScreen extends StatefulWidget {
  const AgregarRepuestoScreen({super.key});

  @override
  State<AgregarRepuestoScreen> createState() => _AgregarRepuestoScreenState();
}

class _AgregarRepuestoScreenState extends State<AgregarRepuestoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codigoCtrl = TextEditingController();
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _stockMinCtrl = TextEditingController(text: '5');
  final _costoCtrl = TextEditingController(text: '0');
  final _ventaCtrl = TextEditingController(text: '0');
  CategoriaRepuesto _categoria = CategoriaRepuesto.otros;
  XFile? _foto;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) setState(() => _foto = image);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final provider = context.read<InventarioProvider>();
    await provider.crearRepuestoConFoto(
      codigoInterno: _codigoCtrl.text.trim(),
      nombre: _nombreCtrl.text.trim(),
      descripcion: _descCtrl.text.trim(),
      categoria: _categoria,
      stockActual: int.tryParse(_stockCtrl.text) ?? 0,
      stockMinimo: int.tryParse(_stockMinCtrl.text) ?? 5,
      precioCosto: double.tryParse(_costoCtrl.text) ?? 0,
      precioVenta: double.tryParse(_ventaCtrl.text) ?? 0,
      foto: _foto,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agregar repuesto cloud')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(controller: _codigoCtrl, decoration: const InputDecoration(labelText: 'Código interno'), validator: (v) => v == null || v.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _nombreCtrl, decoration: const InputDecoration(labelText: 'Nombre'), validator: (v) => v == null || v.isEmpty ? 'Requerido' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Descripción')),
              const SizedBox(height: 12),
              DropdownButtonFormField<CategoriaRepuesto>(
                value: _categoria,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: CategoriaRepuesto.values.map((c) => DropdownMenuItem(value: c, child: Text(c.label))).toList(),
                onChanged: (value) => setState(() => _categoria = value ?? CategoriaRepuesto.otros),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _stockMinCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Stock mínimo'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextFormField(controller: _costoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Costo'))),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(controller: _ventaCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Venta'))),
              ]),
              const SizedBox(height: 16),
              OutlinedButton.icon(onPressed: _pickImage, icon: const Icon(Icons.photo_camera_rounded), label: const Text('Agregar foto')),
              if (_foto != null) ...[
                const SizedBox(height: 12),
                Text('Foto seleccionada: ${_foto!.name}', style: const TextStyle(color: AppTheme.textSecondary)),
              ],
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _save, child: const Text('Guardar repuesto'))),
            ],
          ),
        ),
      ),
    );
  }
}
