import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/core/services/pdf_factura_service.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';

/// La fecha de entrega es la de **entregar la moto**, no la de dejarla lista.
void main() {
  final hoy = DateTime(2026, 10, 8, 9);

  OrdenMantenimiento orden(EstadoOrden estado,
          {DateTime? entrega, DateTime? ingreso}) =>
      OrdenMantenimiento(
        numeroOrden: 'OT-00020',
        clienteId: 'c1',
        vehiculoId: 'v1',
        tipoServicio: 'Mantenimiento',
        kilometrajeIngreso: 1000,
        estado: estado,
        fechaEntrega: entrega,
        fechaIngreso: ingreso,
      );

  group('fecha de la factura', () {
    test('una orden entregada conserva su fecha de entrega al reimprimir', () {
      final o = orden(EstadoOrden.entregada, entrega: DateTime(2026, 9, 1));
      expect(PdfFacturaService.fechaDelDocumento(o, ahora: hoy),
          DateTime(2026, 9, 1));
    });

    test('una orden lista, aunque traiga una fecha vieja, lleva la de hoy', () {
      final o =
          orden(EstadoOrden.listaParaEntrega, entrega: DateTime(2026, 9, 1));
      expect(PdfFacturaService.fechaDelDocumento(o, ahora: hoy), hoy);
    });

    test('una orden sin fecha de entrega lleva la de hoy', () {
      expect(
          PdfFacturaService.fechaDelDocumento(orden(EstadoOrden.enReparacion),
              ahora: hoy),
          hoy);
    });
  });

  group('copyWith y la fecha de entrega', () {
    test('sin pedirlo, la fecha se conserva', () {
      final o = orden(EstadoOrden.entregada, entrega: DateTime(2026, 9, 1));
      expect(o.copyWith(estado: EstadoOrden.entregada).fechaEntrega,
          DateTime(2026, 9, 1));
    });

    test('limpiarFechaEntrega la borra', () {
      final o = orden(EstadoOrden.entregada, entrega: DateTime(2026, 9, 1));
      final c = o.copyWith(
          estado: EstadoOrden.enReparacion, limpiarFechaEntrega: true);
      expect(c.fechaEntrega, isNull);
    });
  });

  group('días en el taller', () {
    test('se detienen al entregar la moto', () {
      final o = orden(EstadoOrden.entregada,
          ingreso: DateTime.now().subtract(const Duration(days: 10)),
          entrega: DateTime.now().subtract(const Duration(days: 7)));
      expect(o.diasEnTaller, 3);
    });

    test('siguen contando mientras la moto esté lista pero sin recoger', () {
      // Antes se congelaban al marcarla lista: una moto olvidada en el taller
      // no se ponía en rojo por mucho que pasaran los días.
      final o = orden(EstadoOrden.listaParaEntrega,
          ingreso: DateTime.now().subtract(const Duration(days: 10)),
          entrega: DateTime.now().subtract(const Duration(days: 8)));
      expect(o.diasEnTaller, 10);
    });
  });
}
