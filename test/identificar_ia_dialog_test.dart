import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moto_taller_app/data/providers/inventario_provider.dart';
import 'package:moto_taller_app/ui/widgets/identificar_ia_dialog.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// «Identificar repuesto por foto», con Gemini.
///
/// **Lo que no se prueba aquí, y conviene tenerlo claro**: ni la cámara, ni la
/// galería, ni la llamada a Gemini. La primera necesita hardware y la última
/// una clave de verdad y red; simularlas no diría nada útil.
///
/// Lo que sí importa comprobar es que la pantalla **arranca ofreciendo lo que
/// debe**, porque la clave se inyecta al compilar (`--dart-define`) y sin ella
/// la función se desactiva sola con un mensaje en vez de reventar con un error
/// de autenticación que al mecánico no le dice nada.
void main() {
  late FuenteDeDatosFalsa db;
  late InventarioProvider inventarioProvider;

  setUp(() {
    db = FuenteDeDatosFalsa();
    inventarioProvider = InventarioProvider(db: db);
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<InventarioProvider>.value(
        value: inventarioProvider,
        child: const MaterialApp(
          home: Scaffold(body: IdentificarIaDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ofrece cámara y galería', (tester) async {
    await montar(tester);

    expect(find.text('CÁMARA'), findsOneWidget);
    expect(find.text('GALERÍA'), findsOneWidget);
    expect(find.text('Toma una foto de la pieza física'), findsOneWidget);
  });

  testWidgets('arranca sin resultado y sin error', (tester) async {
    await montar(tester);

    expect(find.text('SUGERENCIA DE REPARACIÓN'), findsNothing);
    expect(find.text('Reintentar'), findsNothing);
    expect(find.text('AÑADIR A LA VENTA / COTIZACIÓN'), findsNothing);
  });

  testWidgets('no consulta el inventario hasta que hay una foto',
      (tester) async {
    await montar(tester);

    expect(db.llamadas, isEmpty,
        reason: 'abrir el diálogo no debe tocar la base');
  });
}
