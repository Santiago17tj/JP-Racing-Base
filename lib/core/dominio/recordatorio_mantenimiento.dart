import '../../data/models/cliente.dart';
import '../../data/models/orden_mantenimiento.dart';
import '../../data/models/vehiculo.dart';

/// Una moto que ya tocaría traer a revisión.
class RecordatorioMantenimiento {
  const RecordatorioMantenimiento({
    required this.vehiculo,
    required this.cliente,
    required this.ultimaOrden,
    required this.diasDesdeUltimoServicio,
  });

  final Vehiculo vehiculo;
  final Cliente cliente;
  final OrdenMantenimiento ultimaOrden;
  final int diasDesdeUltimoServicio;

  /// Kilometraje con el que entró la última vez. Sirve para calcular cuánto
  /// habrá rodado desde entonces.
  int get kilometrajeUltimoServicio => ultimaOrden.kilometrajeIngreso;

  /// Cuánto se pasó del intervalo recomendado.
  int diasDeAtraso(int intervaloDias) =>
      diasDesdeUltimoServicio - intervaloDias;

  /// Urgencia para ordenar la lista y darle color en pantalla.
  NivelRecordatorio nivel(int intervaloDias) {
    final atraso = diasDeAtraso(intervaloDias);
    if (atraso >= intervaloDias) return NivelRecordatorio.vencido;
    if (atraso >= 0) return NivelRecordatorio.tocaAhora;
    return NivelRecordatorio.proximo;
  }
}

enum NivelRecordatorio {
  /// Se pasó del doble del intervalo: hace mucho que no vuelve.
  vencido,

  /// Ya cumplió el intervalo recomendado.
  tocaAhora,

  /// Se acerca la fecha.
  proximo,
}

/// Calcula a qué clientes hay que llamar para el próximo mantenimiento.
///
/// No hace falta que el taller registre nada extra: se deduce de la última
/// orden entregada de cada moto. Un taller de motos suele citar cada tres
/// meses o cada 3.000 km, de ahí el intervalo por defecto.
class CalculadoraRecordatorios {
  const CalculadoraRecordatorios._();

  /// Intervalo recomendado entre mantenimientos, en días.
  static const int intervaloDiasPorDefecto = 90;

  /// Se avisa desde 15 días antes de que se cumpla el intervalo.
  static const int diasDeAnticipacion = 15;

  static List<RecordatorioMantenimiento> calcular({
    required List<OrdenMantenimiento> ordenes,
    required Map<String, Vehiculo> vehiculosPorId,
    required Map<String, Cliente> clientesPorId,
    int intervaloDias = intervaloDiasPorDefecto,
    DateTime? ahora,
  }) {
    final hoy = ahora ?? DateTime.now();

    // De cada moto interesa únicamente su servicio más reciente.
    final ultimaPorVehiculo = <String, OrdenMantenimiento>{};
    for (final orden in ordenes) {
      final fecha = orden.fechaEntrega ?? orden.fechaIngreso;
      final actual = ultimaPorVehiculo[orden.vehiculoId];
      final fechaActual = actual == null
          ? null
          : (actual.fechaEntrega ?? actual.fechaIngreso);
      if (fechaActual == null || fecha.isAfter(fechaActual)) {
        ultimaPorVehiculo[orden.vehiculoId] = orden;
      }
    }

    final recordatorios = <RecordatorioMantenimiento>[];
    ultimaPorVehiculo.forEach((vehiculoId, orden) {
      final vehiculo = vehiculosPorId[vehiculoId];
      final cliente = clientesPorId[orden.clienteId];
      if (vehiculo == null || cliente == null) return;

      final referencia = orden.fechaEntrega ?? orden.fechaIngreso;
      final dias = hoy.difference(referencia).inDays;

      // Solo entran las que ya se acercan al intervalo.
      if (dias < intervaloDias - diasDeAnticipacion) return;

      recordatorios.add(RecordatorioMantenimiento(
        vehiculo: vehiculo,
        cliente: cliente,
        ultimaOrden: orden,
        diasDesdeUltimoServicio: dias,
      ));
    });

    // Primero las que llevan más tiempo sin volver.
    recordatorios.sort((a, b) =>
        b.diasDesdeUltimoServicio.compareTo(a.diasDesdeUltimoServicio));
    return recordatorios;
  }
}
