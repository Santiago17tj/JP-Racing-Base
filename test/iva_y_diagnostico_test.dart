import 'package:flutter_test/flutter_test.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/ui/widgets/checklist_diagnostico_sheet.dart';

/// Orden de ejemplo: 67.000 en repuestos y 40.000 de mano de obra.
OrdenMantenimiento _orden({double pagado = 0}) => OrdenMantenimiento(
      numeroOrden: 'OT-00001',
      clienteId: 'c1',
      vehiculoId: 'v1',
      tipoServicio: 'Mantenimiento Preventivo',
      kilometrajeIngreso: 85803,
      costoManoObra: 40000,
      subtotalRepuestos: 67000,
      montoPagado: pagado,
    );

void main() {
  group('IVA solo sobre la mano de obra', () {
    test('no grava los repuestos', () {
      final orden = _orden();
      // 19% de 40.000 = 7.600. Si gravara todo serían 20.330.
      expect(orden.impuestoManoObra(19), 7600);
      expect(orden.totalConImpuesto(19), 114600);
    });

    test('con impuesto en cero el total no cambia', () {
      final orden = _orden();
      expect(orden.impuestoManoObra(0), 0);
      expect(orden.totalConImpuesto(0), orden.totalEstimado);
      expect(orden.totalEstimado, 107000);
    });

    test('el saldo pendiente descuenta los abonos y nunca es negativo', () {
      expect(_orden(pagado: 100000).saldoPendienteConImpuesto(19), 14600);
      expect(_orden(pagado: 200000).saldoPendienteConImpuesto(19), 0);
    });
  });

  group('Checklist "¿Qué tiene la moto?"', () {
    test('arma el texto agrupado por sistema', () {
      final texto = ChecklistDiagnosticoSheet.construirTexto(
        {'Aceite de motor': EstadoPunto.cambiar, 'Batería': EstadoPunto.bien},
        'Se entrega el lunes.',
      );

      expect(texto, contains('Motor:'));
      expect(texto, contains('• Aceite de motor: Cambiar'));
      expect(texto, contains('Eléctrico:'));
      expect(texto, contains('• Batería: Bien'));
      expect(texto, contains('Se entrega el lunes.'));
    });

    test('al reabrir conserva lo marcado y las notas escritas a mano', () {
      final original = {
        'Aceite de motor': EstadoPunto.cambiar,
        'Bujía': EstadoPunto.bien,
        'Llanta trasera': EstadoPunto.revisar,
      };
      final texto =
          ChecklistDiagnosticoSheet.construirTexto(original, 'Nota del mecánico');

      final (marcados, libre) = ChecklistDiagnosticoSheet.parsear(texto);

      expect(marcados, original);
      expect(libre, 'Nota del mecánico');
    });

    test('un diagnóstico escrito a mano se conserva íntegro', () {
      const escrito = 'La moto llegó sin frenos y con el tanque rayado.';
      final (marcados, libre) = ChecklistDiagnosticoSheet.parsear(escrito);

      expect(marcados, isEmpty);
      expect(libre, escrito);
    });

    test('sin nada marcado ni escrito el diagnóstico queda vacío', () {
      expect(ChecklistDiagnosticoSheet.construirTexto({}, '   '), '');
    });
  });
}
