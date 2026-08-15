import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/data/models/repuesto.dart';
import 'package:moto_taller_app/data/providers/inventario_provider.dart';
import 'package:moto_taller_app/ui/widgets/escaner_codigo_barras_dialog.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// El escáner de códigos de barras.
///
/// **La cámara no se puede probar aquí**: `MobileScanner` necesita el hardware
/// del teléfono. Lo que sí se prueba —y es lo que de verdad decide qué repuesto
/// entra en la venta— es la **entrada manual**, que recorre exactamente el
/// mismo camino: buscar por código y devolver el repuesto o proponer crearlo.
void main() {
  late FuenteDeDatosFalsa db;
  late InventarioProvider inventarioProvider;

  setUp(() {
    db = FuenteDeDatosFalsa();
    inventarioProvider = InventarioProvider(db: db);
  });

  Repuesto crearRepuesto({String codigo = 'BOM-001'}) {
    final rep = Repuesto(
      codigoInterno: codigo,
      nombre: 'Bomba de aceite nkd',
      categoria: CategoriaRepuesto.otros,
      stockActual: 10,
      stockMinimo: 2,
      precioCosto: 60000,
      precioVenta: 120000,
    );
    db.repuestos.add(rep);
    return rep;
  }

  /// Abre el diálogo y pasa a modo manual. Devuelve lo que acabe devolviendo.
  Future<Repuesto?> abrirEnModoManual(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Repuesto? resultado;
    await tester.pumpWidget(
      ChangeNotifierProvider<InventarioProvider>.value(
        value: inventarioProvider,
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () async {
                    resultado = await showDialog<Repuesto>(
                      context: context,
                      builder: (_) => const EscanerCodigoBarrasDialog(),
                    );
                  },
                  child: const Text('abrir escáner'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir escáner'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ingresar código manual'));
    await tester.pumpAndSettle();
    return resultado;
  }

  testWidgets('deja pasar de la cámara a escribir el código a mano',
      (tester) async {
    crearRepuesto();
    await abrirEnModoManual(tester);

    expect(find.text('Escáner de Código'), findsOneWidget);
    expect(find.text('Usar cámara'), findsOneWidget,
        reason: 'y deja volver a la cámara');
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('un código conocido devuelve su repuesto y cierra',
      (tester) async {
    final rep = crearRepuesto(codigo: 'BOM-001');
    await abrirEnModoManual(tester);

    await tester.enterText(find.byType(TextField), 'bom-001');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Escáner de Código'), findsNothing,
        reason: 'se cierra al encontrarlo');
    expect(db.llamadas['getRepuestoPorCodigo'], isNotNull);
    expect(inventarioProvider.repuestoEscaneado?.id, rep.id);
  });

  testWidgets('el código se busca siempre en mayúsculas', (tester) async {
    // El escáner de la cámara devuelve el código tal cual venga impreso; la
    // entrada manual lo normaliza igual para que los dos caminos coincidan.
    crearRepuesto(codigo: 'BOM-001');
    await abrirEnModoManual(tester);

    await tester.enterText(find.byType(TextField), 'bom-001');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(inventarioProvider.repuestoEscaneado, isNotNull,
        reason: 'en minúsculas no habría encontrado nada');
  });

  testWidgets('un código desconocido ofrece crear el repuesto',
      (tester) async {
    crearRepuesto(codigo: 'BOM-001');
    await abrirEnModoManual(tester);

    await tester.enterText(find.byType(TextField), 'XXX-999');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Código no registrado'), findsOneWidget);
    expect(find.textContaining('XXX-999'), findsWidgets);
    expect(find.text('Crear Repuesto'), findsOneWidget);
  });

  testWidgets('si no se quiere crear, el escáner sigue abierto para reintentar',
      (tester) async {
    crearRepuesto(codigo: 'BOM-001');
    await abrirEnModoManual(tester);

    await tester.enterText(find.byType(TextField), 'XXX-999');
    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Escáner de Código'), findsOneWidget);
    expect(db.repuestos, hasLength(1), reason: 'no se creó nada');
  });

  testWidgets('un campo vacío no busca nada', (tester) async {
    crearRepuesto();
    await abrirEnModoManual(tester);

    await tester.tap(find.byIcon(Icons.arrow_forward_rounded));
    await tester.pumpAndSettle();

    expect(db.llamadas['getRepuestoPorCodigo'], isNull);
    expect(find.text('Escáner de Código'), findsOneWidget);
  });
}
