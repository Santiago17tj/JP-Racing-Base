import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/core/dominio/recordatorio_mantenimiento.dart';
import 'package:moto_taller_app/data/models/cliente.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/data/models/vehiculo.dart';

final _hoy = DateTime(2026, 8, 11);

Cliente _cliente(String id) => Cliente(
      id: id,
      nombre: 'Cliente',
      apellido: id,
      tipoDocumento: TipoDocumento.cc,
      numeroDocumento: '123',
      telefono: '3160000000',
    );

Vehiculo _vehiculo(String id, String clienteId) => Vehiculo(
      id: id,
      clienteId: clienteId,
      placaPatente: 'ABC$id',
      marca: 'Suzuki',
      modelo: 'Best',
      anio: 2020,
    );

OrdenMantenimiento _orden({
  required String vehiculoId,
  required String clienteId,
  required int diasAtras,
  int km = 10000,
}) =>
    OrdenMantenimiento(
      numeroOrden: 'OT-$vehiculoId',
      clienteId: clienteId,
      vehiculoId: vehiculoId,
      tipoServicio: 'Mantenimiento Preventivo',
      kilometrajeIngreso: km,
      fechaIngreso: _hoy.subtract(Duration(days: diasAtras + 1)),
      fechaEntrega: _hoy.subtract(Duration(days: diasAtras)),
    );

List<RecordatorioMantenimiento> _calcular(List<OrdenMantenimiento> ordenes) =>
    CalculadoraRecordatorios.calcular(
      ordenes: ordenes,
      vehiculosPorId: {
        for (final o in ordenes) o.vehiculoId: _vehiculo(o.vehiculoId, o.clienteId)
      },
      clientesPorId: {for (final o in ordenes) o.clienteId: _cliente(o.clienteId)},
      ahora: _hoy,
    );

void main() {
  test('una moto atendida la semana pasada no genera recordatorio', () {
    final r = _calcular([_orden(vehiculoId: 'v1', clienteId: 'c1', diasAtras: 7)]);
    expect(r, isEmpty);
  });

  test('avisa 15 días antes de cumplir el intervalo', () {
    // 90 - 15 = 75 días: justo cuando debe empezar a aparecer.
    expect(_calcular([_orden(vehiculoId: 'v1', clienteId: 'c1', diasAtras: 74)]),
        isEmpty);
    expect(_calcular([_orden(vehiculoId: 'v1', clienteId: 'c1', diasAtras: 75)]),
        hasLength(1));
  });

  test('clasifica la urgencia según el atraso', () {
    const intervalo = CalculadoraRecordatorios.intervaloDiasPorDefecto;

    final proximo =
        _calcular([_orden(vehiculoId: 'v1', clienteId: 'c1', diasAtras: 80)]);
    expect(proximo.single.nivel(intervalo), NivelRecordatorio.proximo);

    final toca =
        _calcular([_orden(vehiculoId: 'v1', clienteId: 'c1', diasAtras: 100)]);
    expect(toca.single.nivel(intervalo), NivelRecordatorio.tocaAhora);

    final vencido =
        _calcular([_orden(vehiculoId: 'v1', clienteId: 'c1', diasAtras: 200)]);
    expect(vencido.single.nivel(intervalo), NivelRecordatorio.vencido);
  });

  test('de cada moto toma solo su servicio más reciente', () {
    final r = _calcular([
      _orden(vehiculoId: 'v1', clienteId: 'c1', diasAtras: 300),
      _orden(vehiculoId: 'v1', clienteId: 'c1', diasAtras: 100),
    ]);
    expect(r, hasLength(1));
    expect(r.single.diasDesdeUltimoServicio, 100);
  });

  test('ordena primero a quien lleva más tiempo sin volver', () {
    final r = _calcular([
      _orden(vehiculoId: 'v1', clienteId: 'c1', diasAtras: 100),
      _orden(vehiculoId: 'v2', clienteId: 'c2', diasAtras: 250),
      _orden(vehiculoId: 'v3', clienteId: 'c3', diasAtras: 90),
    ]);
    expect(r.map((x) => x.diasDesdeUltimoServicio), [250, 100, 90]);
  });
}
