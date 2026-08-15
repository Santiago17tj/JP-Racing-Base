import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moto_taller_app/core/services/rescate_sincronizacion_service.dart';
import 'package:moto_taller_app/ui/screens/rescate_datos_screen.dart';

/// La pantalla que responde a «¿mis datos están a salvo?».
///
/// Su única razón de ser es que **lo que se ve en el teléfono no prueba nada**:
/// la app siempre pinta lo local. Si esta pantalla dijera «todo subido» cuando
/// no lo está, sería peor que no tenerla.
class _ServicioFalso extends RescateSincronizacionService {
  const _ServicioFalso({
    required this.diagnostico,
    this.subida,
  });

  final ResultadoRescate diagnostico;
  final ResultadoRescate? subida;

  @override
  Future<ResultadoRescate> diagnosticar() async => diagnostico;

  @override
  Future<ResultadoRescate> subirPendientes() async => subida ?? diagnostico;
}

void main() {
  Future<void> montar(
    WidgetTester tester, {
    required ResultadoRescate diagnostico,
    ResultadoRescate? subida,
  }) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: RescateDatosScreen(
          servicio: _ServicioFalso(diagnostico: diagnostico, subida: subida),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ResultadoRescate diagnosticoCon({
    int local = 0,
    int nube = 0,
    int faltantes = 0,
    int omitidas = 0,
    int deOtraCuenta = 0,
    List<String> fallos = const [],
    bool ejecutado = false,
    int repuestosCreados = 0,
    int pagosActualizados = 0,
  }) =>
      ResultadoRescate(
        tablas: [
          ConteoTabla(
            tabla: 'orden_items',
            etiqueta: 'Repuestos de órdenes',
            local: local,
            nube: nube,
            faltantes: faltantes,
            omitidas: omitidas,
            deOtraCuenta: deOtraCuenta,
          ),
        ],
        fallos: fallos,
        ejecutado: ejecutado,
        repuestosCreados: repuestosCreados,
        pagosActualizados: pagosActualizados,
      );

  testWidgets('enseña el recuento del teléfono contra el de la nube',
      (tester) async {
    await montar(tester, diagnostico: diagnosticoCon(local: 14, nube: 12, faltantes: 2));

    expect(find.text('Teléfono contra nube'), findsOneWidget);
    expect(find.text('Repuestos de órdenes'), findsOneWidget);
    expect(find.text('14'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('en la nube'), findsOneWidget);
    expect(find.text('2 cambios sin subir.'), findsOneWidget);
  });

  testWidgets('con un solo pendiente lo dice en singular', (tester) async {
    await montar(tester, diagnostico: diagnosticoCon(local: 13, nube: 12, faltantes: 1));

    expect(find.text('1 cambio sin subir.'), findsOneWidget);
  });

  testWidgets('sin nada pendiente lo dice claro', (tester) async {
    await montar(tester, diagnostico: diagnosticoCon(local: 12, nube: 12));

    expect(find.text('No queda nada por subir.'), findsOneWidget);
  });

  testWidgets('la nube con más filas que el teléfono no es un problema',
      (tester) async {
    // Pasa cuando el taller usa dos aparatos. Verde significa «no falta nada
    // por subir», no «los números coinciden».
    await montar(tester, diagnostico: diagnosticoCon(local: 4, nube: 14));

    expect(find.text('No queda nada por subir.'), findsOneWidget);
  });

  testWidgets('las filas que nunca podrán subir se informan aparte',
      (tester) async {
    // Los datos de demostración con ids inventados. Contarlos como pendientes
    // dejaría el aviso de «N cambios sin subir» encendido para siempre.
    await montar(tester, diagnostico: diagnosticoCon(local: 8, nube: 2, omitidas: 6));

    expect(find.text('6 filas que no se envían'), findsOneWidget);
    expect(find.text('No queda nada por subir.'), findsOneWidget);
  });

  testWidgets('las filas de otra cuenta también van aparte', (tester) async {
    await montar(tester, diagnostico: diagnosticoCon(local: 20, nube: 12, deOtraCuenta: 8));

    expect(find.text('8 filas de otra cuenta'), findsOneWidget);
    expect(find.text('No queda nada por subir.'), findsOneWidget);
  });

  group('después de subir', () {
    testWidgets('si quedó todo arriba lo confirma', (tester) async {
      await montar(
        tester,
        diagnostico: diagnosticoCon(local: 14, nube: 12, faltantes: 2),
        subida: diagnosticoCon(local: 14, nube: 14, ejecutado: true),
      );

      await tester.tap(find.text('Subir lo que falta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Subir'));
      await tester.pumpAndSettle();

      expect(find.text('Todo subido'), findsOneWidget);
      expect(find.text('No queda nada por subir.'), findsOneWidget);
    });

    testWidgets('si algo falló lo dice y enseña el error textual',
        (tester) async {
      // Esto es lo que estuvo meses invisible: el error real del servidor.
      await montar(
        tester,
        diagnostico: diagnosticoCon(local: 14, nube: 12, faltantes: 2),
        subida: diagnosticoCon(
          local: 14,
          nube: 13,
          faltantes: 1,
          ejecutado: true,
          fallos: const ['orden_items: 22P02 identificador antiguo'],
        ),
      );

      await tester.tap(find.text('Subir lo que falta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Subir'));
      await tester.pumpAndSettle();

      expect(find.text('Quedó trabajo sin hacer'), findsOneWidget);
      expect(find.text('Lo que no se pudo subir (1)'), findsOneWidget);
      expect(find.textContaining('22P02'), findsOneWidget);
      expect(find.text('Todo subido'), findsNothing);
    });

    testWidgets('informa de los arreglos que hizo por el camino',
        (tester) async {
      await montar(
        tester,
        diagnostico: diagnosticoCon(local: 14, nube: 12, faltantes: 2),
        subida: diagnosticoCon(
          local: 14,
          nube: 14,
          ejecutado: true,
          repuestosCreados: 3,
          pagosActualizados: 2,
        ),
      );

      await tester.tap(find.text('Subir lo que falta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Subir'));
      await tester.pumpAndSettle();

      expect(find.textContaining('2 orden(es) con su estado de pago corregido'),
          findsOneWidget);
      expect(
          find.textContaining('3 repuesto(s) creados en el inventario de la nube'),
          findsOneWidget);
    });

    testWidgets('cancelar la confirmación no sube nada', (tester) async {
      await montar(
        tester,
        diagnostico: diagnosticoCon(local: 14, nube: 12, faltantes: 2),
        subida: diagnosticoCon(local: 14, nube: 14, ejecutado: true),
      );

      await tester.tap(find.text('Subir lo que falta'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(find.text('Todo subido'), findsNothing);
      expect(find.text('2 cambios sin subir.'), findsOneWidget);
    });
  });

  testWidgets('sin pendientes el botón invita a repetir sin miedo',
      (tester) async {
    // El rescate es idempotente: compara por `id` y no sobreescribe nada.
    await montar(tester, diagnostico: diagnosticoCon(local: 12, nube: 12));

    expect(find.text('Subir de nuevo (no duplica nada)'), findsOneWidget);
  });

  testWidgets('avisa de que lo que se ve en pantalla no prueba nada',
      (tester) async {
    await montar(tester, diagnostico: diagnosticoCon());

    expect(find.textContaining('verlos completos en pantalla no significa'),
        findsOneWidget);
  });
}
