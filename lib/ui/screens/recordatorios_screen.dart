import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/dominio/recordatorio_mantenimiento.dart';
import '../../core/theme/app_theme.dart';
import '../../data/providers/ordenes_provider.dart';
import '../../data/providers/taller_provider.dart';

/// Clientes a los que toca llamar para el próximo mantenimiento.
///
/// Es la pantalla que hace que la moto vuelva al taller: se calcula sola con
/// la última orden de cada moto, sin que nadie tenga que agendar nada.
class RecordatoriosScreen extends StatefulWidget {
  const RecordatoriosScreen({super.key});

  @override
  State<RecordatoriosScreen> createState() => _RecordatoriosScreenState();
}

class _RecordatoriosScreenState extends State<RecordatoriosScreen> {
  int _intervaloDias = CalculadoraRecordatorios.intervaloDiasPorDefecto;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<OrdenesProvider>();
      // El historial completo es la fuente: sin él no hay a quién llamar.
      if (provider.hayMasHistorial) provider.cargarMasHistorial();
    });
  }

  Future<void> _escribir(RecordatorioMantenimiento r) async {
    final telefono = r.cliente.telefono.replaceAll(RegExp(r'[^0-9]'), '');
    if (telefono.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese cliente no tiene teléfono guardado.')),
      );
      return;
    }
    final numero = telefono.length <= 10 ? '57$telefono' : telefono;

    final taller = context.read<TallerProvider>().taller;
    final nombreTaller = (taller?.nombreTaller ?? '').trim().isNotEmpty
        ? taller!.nombreTaller
        : 'el taller';

    final mensaje = '¡Hola ${r.cliente.nombre}! Le escribimos de $nombreTaller. '
        'Su ${r.vehiculo.marca} ${r.vehiculo.modelo} (${r.vehiculo.placaPatente}) '
        'tuvo su último servicio hace ${r.diasDesdeUltimoServicio} días. '
        '¿Le agendamos el mantenimiento?';

    final url = Uri.parse(
        'https://wa.me/$numero?text=${Uri.encodeComponent(mensaje)}');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir WhatsApp: $e')),
        );
      }
    }
  }

  Color _color(NivelRecordatorio nivel) => switch (nivel) {
        NivelRecordatorio.vencido => AppTheme.error,
        NivelRecordatorio.tocaAhora => AppTheme.warning,
        NivelRecordatorio.proximo => AppTheme.primaryLight,
      };

  String _etiqueta(NivelRecordatorio nivel) => switch (nivel) {
        NivelRecordatorio.vencido => 'HACE MUCHO',
        NivelRecordatorio.tocaAhora => 'YA TOCA',
        NivelRecordatorio.proximo => 'PRÓXIMO',
      };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OrdenesProvider>();

    final recordatorios = CalculadoraRecordatorios.calcular(
      ordenes: [...provider.historial, ...provider.ordenesActivas],
      vehiculosPorId: provider.vehiculosPorId,
      clientesPorId: provider.clientesPorId,
      intervaloDias: _intervaloDias,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Próximos Mantenimientos')),
      body: Column(
        children: [
          _buildSelectorIntervalo(),
          Expanded(
            child: recordatorios.isEmpty
                ? _buildVacio()
                : ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.spacingMd),
                    itemCount: recordatorios.length,
                    itemBuilder: (context, i) => _buildTarjeta(recordatorios[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectorIntervalo() {
    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacingMd, AppTheme.spacingMd,
          AppTheme.spacingMd, 0),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          const Icon(Icons.event_repeat_rounded,
              color: AppTheme.primaryLight, size: 20),
          const SizedBox(width: AppTheme.spacingSm),
          const Expanded(
            child: Text(
              'Avisar cada',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
          ),
          DropdownButton<int>(
            value: _intervaloDias,
            underline: const SizedBox(),
            dropdownColor: AppTheme.surface,
            items: const [
              DropdownMenuItem(value: 60, child: Text('2 meses')),
              DropdownMenuItem(value: 90, child: Text('3 meses')),
              DropdownMenuItem(value: 120, child: Text('4 meses')),
              DropdownMenuItem(value: 180, child: Text('6 meses')),
            ],
            onChanged: (v) => setState(() => _intervaloDias = v ?? 90),
          ),
        ],
      ),
    );
  }

  Widget _buildVacio() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spacingLg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded,
                size: 48, color: AppTheme.textTertiary),
            SizedBox(height: AppTheme.spacingMd),
            Text(
              'Ninguna moto está pendiente',
              style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold),
            ),
            SizedBox(height: AppTheme.spacingXs),
            Text(
              'Cuando una moto lleve tiempo sin volver, aparecerá aquí con el botón para escribirle al dueño.',
              style: TextStyle(color: AppTheme.textTertiary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjeta(RecordatorioMantenimiento r) {
    final nivel = r.nivel(_intervaloDias);
    final color = _color(nivel);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingSm),
      padding: const EdgeInsets.all(AppTheme.spacingMd),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${r.vehiculo.marca} ${r.vehiculo.modelo}',
                  style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _etiqueta(nivel),
                  style: TextStyle(
                      color: color, fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${r.vehiculo.placaPatente}  ·  ${r.cliente.nombreCompleto}',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            'Último servicio hace ${r.diasDesdeUltimoServicio} días '
            '(${r.ultimaOrden.numeroOrden}, ${r.kilometrajeUltimoServicio} km)',
            style: const TextStyle(color: AppTheme.textTertiary, fontSize: 11),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _escribir(r),
              icon: const Icon(Icons.chat_rounded,
                  size: 18, color: AppTheme.success),
              label: const Text('Escribirle por WhatsApp'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.success,
                side: const BorderSide(color: AppTheme.surfaceBorder),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
