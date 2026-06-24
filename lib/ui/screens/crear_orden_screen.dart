import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/enums.dart';
import '../../data/models/cliente.dart';
import '../../data/models/vehiculo.dart';
import '../../data/providers/ordenes_provider.dart';

/// Pantalla para el registro de ingreso (Check-in) de una motocicleta.
class CrearOrdenScreen extends StatefulWidget {
  const CrearOrdenScreen({super.key});

  @override
  State<CrearOrdenScreen> createState() => _CrearOrdenScreenState();
}

class _CrearOrdenScreenState extends State<CrearOrdenScreen> {
  final _formKey = GlobalKey<FormState>();

  // Control de flujo: ¿Cliente existente o nuevo?
  bool _esNuevoCliente = true;

  // Clientes y vehículos seleccionados en modo existente
  Cliente? _clienteSeleccionado;
  Vehiculo? _vehiculoSeleccionado;
  List<Vehiculo> _vehiculosDelCliente = [];

  // Controladores de texto para Cliente Nuevo
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _documentoCtrl = TextEditingController();

  // Controladores de texto para Vehículo Nuevo
  final _placaCtrl = TextEditingController();
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _anioCtrl = TextEditingController();

  // Controladores de texto para la Orden
  final _kilometrajeCtrl = TextEditingController();
  final _problemaCtrl = TextEditingController();
  final _mecanicoCtrl = TextEditingController();

  TipoServicio _tipoServicio = TipoServicio.preventivo;

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _telefonoCtrl.dispose();
    _documentoCtrl.dispose();
    _placaCtrl.dispose();
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _anioCtrl.dispose();
    _kilometrajeCtrl.dispose();
    _problemaCtrl.dispose();
    _mecanicoCtrl.dispose();
    super.dispose();
  }

  Future<void> _actualizarVehiculos(String clienteId) async {
    final provider = context.read<OrdenesProvider>();
    final vehs = await provider.obtenerVehiculosDeCliente(clienteId);
    setState(() {
      _vehiculosDelCliente = vehs;
      _vehiculoSeleccionado = vehs.isNotEmpty ? vehs.first : null;
      if (_vehiculoSeleccionado != null) {
        _kilometrajeCtrl.text = _vehiculoSeleccionado!.kilometrajeActual.toString();
      } else {
        _kilometrajeCtrl.clear();
      }
    });
  }

  void _guardarOrden() {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<OrdenesProvider>();
    HapticFeedback.mediumImpact();

    if (_esNuevoCliente) {
      provider.crearOrdenRapida(
        nombreCliente: _nombreCtrl.text.trim(),
        apellidoCliente: _apellidoCtrl.text.trim(),
        telefonoCliente: _telefonoCtrl.text.trim(),
        numeroDocumentoCliente: _documentoCtrl.text.trim(),
        placaPatente: _placaCtrl.text.trim().toUpperCase(),
        marca: _marcaCtrl.text.trim(),
        modelo: _modeloCtrl.text.trim(),
        anio: int.tryParse(_anioCtrl.text) ?? DateTime.now().year,
        kilometrajeIngreso: int.tryParse(_kilometrajeCtrl.text) ?? 0,
        descripcionProblema: _problemaCtrl.text.trim(),
        mecanicoAsignado: _mecanicoCtrl.text.trim(),
        tipoServicio: _tipoServicio,
      );
    } else {
      if (_clienteSeleccionado == null || _vehiculoSeleccionado == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debe seleccionar un cliente y vehículo')),
        );
        return;
      }
      provider.crearOrdenClienteExistente(
        clienteId: _clienteSeleccionado!.id,
        vehiculoId: _vehiculoSeleccionado!.id,
        kilometrajeIngreso: int.tryParse(_kilometrajeCtrl.text) ?? 0,
        descripcionProblema: _problemaCtrl.text.trim(),
        mecanicoAsignado: _mecanicoCtrl.text.trim(),
        tipoServicio: _tipoServicio,
      );
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.success),
            SizedBox(width: 8),
            Text('Orden de servicio registrada exitosamente'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdenesProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in de Motocicleta'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            // Selección de tipo de cliente
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Nuevo Cliente'),
                    selected: _esNuevoCliente,
                    onSelected: (selected) {
                      setState(() {
                        _esNuevoCliente = true;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Cliente Existente'),
                    selected: !_esNuevoCliente,
                    onSelected: (selected) {
                      setState(() {
                        _esNuevoCliente = false;
                        if (provider.clientes.isNotEmpty) {
                          _clienteSeleccionado = provider.clientes.first;
                          _actualizarVehiculos(_clienteSeleccionado!.id);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // ── SECCIÓN 1: DATOS DEL CLIENTE ──
            _esNuevoCliente ? _buildNuevoClienteForm() : _buildClienteExistenteForm(provider),
            const SizedBox(height: AppTheme.spacingLg),

            // ── SECCIÓN 2: DATOS DEL VEHÍCULO ──
            if (_esNuevoCliente) _buildNuevoVehiculoForm() else _buildVehiculoExistenteForm(),
            const SizedBox(height: AppTheme.spacingLg),

            // ── SECCIÓN 3: DETALLE DEL TRABAJO ──
            const Text(
              'DETALLES DE INGRESO',
              style: TextStyle(
                color: AppTheme.primaryLight,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacingMd),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  // Tipo de Servicio Dropdown
                  DropdownButtonFormField<TipoServicio>(
                    value: _tipoServicio,
                    decoration: const InputDecoration(labelText: 'Tipo de Servicio'),
                    dropdownColor: AppTheme.surface,
                    items: TipoServicio.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _tipoServicio = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),

                  // Kilometraje de ingreso
                  TextFormField(
                    controller: _kilometrajeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kilometraje de Ingreso',
                      prefixIcon: Icon(Icons.speed, color: AppTheme.textTertiary),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),

                  // Mecánico Asignado
                  TextFormField(
                    controller: _mecanicoCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Mecánico Responsable',
                      prefixIcon: Icon(Icons.engineering_rounded, color: AppTheme.textTertiary),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),

                  // Descripción del problema
                  TextFormField(
                    controller: _problemaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Problema que reporta el cliente',
                      hintText: 'Ej. Ruidos al frenar, jaloneo en baja, cambio de aceite...',
                      alignLabelWithHint: true,
                    ),
                    maxLines: 3,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Botón de envío
            ElevatedButton(
              onPressed: _guardarOrden,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: const Text(
                'REGISTRAR CHECK-IN',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spacingXl),
          ],
        ),
      ),
    );
  }

  Widget _buildNuevoClienteForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INFORMACIÓN DEL CLIENTE NUEVO',
          style: TextStyle(
            color: AppTheme.primaryLight,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: AppTheme.cardDecoration,
          child: Column(
            children: [
              TextFormField(
                controller: _nombreCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _apellidoCtrl,
                decoration: const InputDecoration(labelText: 'Apellido'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _documentoCtrl,
                decoration: const InputDecoration(labelText: 'Documento / DNI / Cédula'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telefonoCtrl,
                decoration: const InputDecoration(labelText: 'Teléfono de Contacto'),
                keyboardType: TextInputType.phone,
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClienteExistenteForm(OrdenesProvider provider) {
    if (provider.clientes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        decoration: AppTheme.cardDecoration,
        child: const Center(
          child: Text('No hay clientes registrados en la base de datos.'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECCIONAR CLIENTE EXISTENTE',
          style: TextStyle(
            color: AppTheme.primaryLight,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: AppTheme.cardDecoration,
          child: DropdownButtonFormField<Cliente>(
            value: _clienteSeleccionado,
            dropdownColor: AppTheme.surface,
            decoration: const InputDecoration(labelText: 'Cliente'),
            items: provider.clientes.map((c) {
              return DropdownMenuItem(
                value: c,
                child: Text('${c.nombreCompleto} (${c.numeroDocumento})'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _clienteSeleccionado = value;
                  _actualizarVehiculos(value.id);
                });
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNuevoVehiculoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INFORMACIÓN DE LA MOTOCICLETA',
          style: TextStyle(
            color: AppTheme.primaryLight,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: AppTheme.cardDecoration,
          child: Column(
            children: [
              TextFormField(
                controller: _placaCtrl,
                decoration: const InputDecoration(labelText: 'Placa / Patente'),
                textCapitalization: TextCapitalization.characters,
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _marcaCtrl,
                      decoration: const InputDecoration(labelText: 'Marca'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _modeloCtrl,
                      decoration: const InputDecoration(labelText: 'Modelo'),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _anioCtrl,
                decoration: const InputDecoration(labelText: 'Año'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Requerido';
                  final val = int.tryParse(v);
                  if (val == null || val < 1970 || val > DateTime.now().year + 1) {
                    return 'Año inválido';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVehiculoExistenteForm() {
    if (_clienteSeleccionado == null) {
      return const SizedBox.shrink();
    }

    if (_vehiculosDelCliente.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MOTOCICLETA DEL CLIENTE',
            style: TextStyle(
              color: AppTheme.primaryLight,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            decoration: AppTheme.cardDecoration,
            child: const Center(
              child: Text(
                'El cliente seleccionado no tiene motos registradas. Registre al cliente como "Nuevo Cliente" para agregar su primera moto.',
                style: TextStyle(color: AppTheme.textTertiary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SELECCIONAR VEHÍCULO',
          style: TextStyle(
            color: AppTheme.primaryLight,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppTheme.spacingSm),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          decoration: AppTheme.cardDecoration,
          child: DropdownButtonFormField<Vehiculo>(
            value: _vehiculoSeleccionado,
            dropdownColor: AppTheme.surface,
            decoration: const InputDecoration(labelText: 'Motocicleta'),
            items: _vehiculosDelCliente.map((v) {
              return DropdownMenuItem(
                value: v,
                child: Text('${v.marca} ${v.modelo} [${v.placaPatente}]'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _vehiculoSeleccionado = value;
                  _kilometrajeCtrl.text = value.kilometrajeActual.toString();
                });
              }
            },
          ),
        ),
      ],
    );
  }
}
