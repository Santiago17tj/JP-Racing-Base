import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moto_taller_app/ui/widgets/checklist_diagnostico_sheet.dart';

/// La hoja de «¿Qué tiene la moto?».
///
/// Vuelca lo marcado al campo de diagnóstico de la orden. Lo delicado es que
/// **se puede reabrir**: tiene que reconocer lo que ella misma escribió y, a la
/// vez, no tocar las notas que el mecánico haya escrito a mano.
void main() {
  Future<String?> abrirYOperar(
    WidgetTester tester,
    String diagnosticoActual,
    Future<void> Function(WidgetTester tester) operar,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? resultado;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  resultado = await ChecklistDiagnosticoSheet.mostrar(
                      context, diagnosticoActual);
                },
                child: const Text('abrir checklist'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir checklist'));
    await tester.pumpAndSettle();

    await operar(tester);
    await tester.pumpAndSettle();
    return resultado;
  }

  /// Marca un punto con el estado indicado, desplegando antes su sistema.
  ///
  /// Los sistemas arrancan cerrados mientras no tengan nada marcado, así que
  /// sus puntos ni siquiera están en el árbol hasta que se despliegan.
  Future<void> marcar(WidgetTester tester, String sistema, String punto,
      String estado) async {
    if (find.text(punto).evaluate().isEmpty) {
      await tester.ensureVisible(find.text(sistema));
      await tester.pumpAndSettle();
      await tester.tap(find.text(sistema));
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(find.text(punto));
    await tester.pumpAndSettle();
    final fila = find.ancestor(
      of: find.text(punto),
      matching: find.byType(Row),
    );
    await tester
        .tap(find.descendant(of: fila.first, matching: find.text(estado)));
    await tester.pumpAndSettle();
  }

  group('el texto que produce', () {
    testWidgets('agrupa lo marcado por sistema', (tester) async {
      final resultado = await abrirYOperar(tester, '', (t) async {
        await marcar(t, 'Transmisión', 'Cadena', 'Cambiar');
        await t.tap(find.text('APLICAR AL DIAGNÓSTICO'));
      });

      expect(resultado, isNotNull);
      expect(resultado, contains('ESTADO DE LA MOTO:'));
      expect(resultado, contains('Transmisión:'));
      expect(resultado, contains('• Cadena: Cambiar'));
    });

    testWidgets('conserva las notas escritas a mano', (tester) async {
      final resultado = await abrirYOperar(tester, '', (t) async {
        await marcar(t, 'Transmisión', 'Cadena', 'Revisar');
        await t.enterText(
            find.byType(TextField), 'El cliente dice que suena en frío');
        await t.tap(find.text('APLICAR AL DIAGNÓSTICO'));
      });

      expect(resultado, contains('• Cadena: Revisar'));
      expect(resultado, contains('El cliente dice que suena en frío'));
    });

    testWidgets('sin nada marcado devuelve solo las notas', (tester) async {
      final resultado = await abrirYOperar(tester, '', (t) async {
        await t.enterText(find.byType(TextField), 'Solo una nota');
        await t.tap(find.text('APLICAR AL DIAGNÓSTICO'));
      });

      expect(resultado, 'Solo una nota');
      expect(resultado, isNot(contains('ESTADO DE LA MOTO:')));
    });
  });

  group('reabrir', () {
    testWidgets('reconoce lo que ella misma escribió', (tester) async {
      final previo = ChecklistDiagnosticoSheet.construirTexto(
        const {},
        '',
      );
      expect(previo, isEmpty);

      const guardado = 'ESTADO DE LA MOTO:\n'
          'Transmisión:\n'
          '• Cadena: Cambiar\n';

      final resultado = await abrirYOperar(tester, guardado, (t) async {
        expect(find.text('1 punto marcado'), findsOneWidget);
        await t.tap(find.text('APLICAR AL DIAGNÓSTICO'));
      });

      expect(resultado, contains('• Cadena: Cambiar'));
    });

    testWidgets('no se come las notas que ya había, aunque no las entienda',
        (tester) async {
      // Es la trampa: la nota libre puede llevar conceptos de mano de obra ya
      // cobrados. Si la hoja los borrara al reabrirse, desaparecerían del
      // diagnóstico sin que nadie se enterara.
      const guardado = 'ESTADO DE LA MOTO:\n'
          'Transmisión:\n'
          '• Cadena: Cambiar\n'
          '\n'
          'Mano de obra: sincronización de válvulas';

      final resultado = await abrirYOperar(tester, guardado, (t) async {
        await t.tap(find.text('APLICAR AL DIAGNÓSTICO'));
      });

      expect(resultado, contains('• Cadena: Cambiar'));
      expect(resultado, contains('Mano de obra: sincronización de válvulas'));
    });
  });

  group('marcar y desmarcar', () {
    testWidgets('tocar dos veces el mismo estado desmarca el punto',
        (tester) async {
      final resultado = await abrirYOperar(tester, '', (t) async {
        await marcar(t, 'Transmisión', 'Cadena', 'Cambiar');
        expect(find.text('1 punto marcado'), findsOneWidget);
        await marcar(t, 'Transmisión', 'Cadena', 'Cambiar');
        expect(find.text('Marca el estado de cada punto revisado'),
            findsOneWidget);
        await t.tap(find.text('APLICAR AL DIAGNÓSTICO'));
      });

      expect(resultado, isEmpty);
    });

    testWidgets('«Limpiar» quita todo lo marcado', (tester) async {
      final resultado = await abrirYOperar(tester, '', (t) async {
        await marcar(t, 'Transmisión', 'Cadena', 'Cambiar');
        await marcar(t, 'Motor', 'Bujía', 'Revisar');
        expect(find.text('2 puntos marcados'), findsOneWidget);

        await t.tap(find.text('Limpiar'));
        await t.pumpAndSettle();
        expect(find.text('Marca el estado de cada punto revisado'),
            findsOneWidget);
        await t.tap(find.text('APLICAR AL DIAGNÓSTICO'));
      });

      expect(resultado, isEmpty);
    });

    testWidgets('cerrar con la X no devuelve nada', (tester) async {
      final resultado = await abrirYOperar(tester, '', (t) async {
        await marcar(t, 'Transmisión', 'Cadena', 'Cambiar');
        await t.tap(find.byTooltip('Cerrar'));
      });

      expect(resultado, isNull,
          reason: 'cancelar no debe pisar el diagnóstico que ya había');
    });
  });

  group('parsear / construir, sin pantalla', () {
    test('lo construido se vuelve a leer igual', () {
      const seleccion = {'Cadena': EstadoPunto.cambiar, 'Bujía': EstadoPunto.bien};
      const nota = 'Revisar de nuevo en 500 km';

      final texto = ChecklistDiagnosticoSheet.construirTexto(seleccion, nota);
      final (leido, resto) = ChecklistDiagnosticoSheet.parsear(texto);

      expect(leido, seleccion);
      expect(resto, nota);
    });

    test('un diagnóstico escrito enteramente a mano se conserva entero', () {
      const aMano = 'Le falta aceite y hace ruido el motor.';
      final (leido, resto) = ChecklistDiagnosticoSheet.parsear(aMano);

      expect(leido, isEmpty);
      expect(resto, aMano);
    });
  });
}
