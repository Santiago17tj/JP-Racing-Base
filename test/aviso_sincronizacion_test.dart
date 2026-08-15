import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moto_taller_app/core/services/rescate_sincronizacion_service.dart';
import 'package:moto_taller_app/ui/widgets/aviso_sincronizacion.dart';

/// La franja de «N cambios sin subir».
///
/// Es la pieza que hace visible el fallo que estuvo meses invisible: la app
/// escribe con «intento la nube, si falla uso local» y cada `catch` solo hacía
/// `debugPrint`, anulado en release. Si esta franja deja de aparecer, se vuelve
/// al escenario en el que el taller veía todo bien con la nube vacía.
class _ServicioFalso extends RescateSincronizacionService {
  const _ServicioFalso(this.pendientes);

  final int pendientes;

  @override
  Future<int> contarPendientes() async => pendientes;
}

void main() {
  Future<void> montar(WidgetTester tester, int pendientes) async {
    tester.view.physicalSize = const Size(1000, 400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AvisoSincronizacion(servicio: _ServicioFalso(pendientes)),
              const Expanded(child: Center(child: Text('tablero'))),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sin nada pendiente no se ve ni se ocupa espacio',
      (tester) async {
    await montar(tester, 0);

    expect(find.textContaining('sin subir'), findsNothing);
    expect(find.text('Revisar'), findsNothing);
    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
    expect(find.text('tablero'), findsOneWidget);
  });

  testWidgets('con varios pendientes avisa con el número exacto',
      (tester) async {
    await montar(tester, 7);

    expect(find.text('7 cambios sin subir a la nube'), findsOneWidget);
    expect(find.text('Revisar'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
  });

  testWidgets('con uno solo lo dice en singular', (tester) async {
    await montar(tester, 1);

    expect(find.text('1 cambio sin subir a la nube'), findsOneWidget);
    expect(find.text('1 cambios sin subir a la nube'), findsNothing);
  });

  testWidgets('si no puede comprobar se calla en vez de inventar una alarma',
      (tester) async {
    // `contarPendientes` se traga cualquier excepción y devuelve 0: sin
    // internet o sin sesión no hay forma de saberlo, y una alarma falsa cada
    // vez que se va la señal haría que el mecánico dejara de mirarla.
    await montar(tester, 0);

    expect(find.byIcon(Icons.cloud_off_rounded), findsNothing);
  });

  testWidgets('el servicio real no requiere argumentos', (tester) async {
    // La franja se usa así en `home_shell`. Si alguien hiciera obligatorio el
    // parámetro de pruebas, la app dejaría de compilar y esto lo detecta antes.
    const aviso = AvisoSincronizacion();
    expect(aviso.servicio, isNull);
  });
}
