import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'package:moto_taller_app/data/models/perfil_taller.dart';
import 'package:moto_taller_app/data/models/registro_caja.dart';
import 'package:moto_taller_app/data/providers/ordenes_provider.dart';
import 'package:moto_taller_app/data/providers/taller_provider.dart';
import 'package:moto_taller_app/ui/screens/contabilidad_screen.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// La caja del taller: lo que entró, lo que salió y lo que queda.
///
/// Las cifras esperadas se escriben a mano; el formateador solo les da forma.
void main() {
  String pesos(num monto) => CurrencyFormatter.format(monto.toDouble());

  late FuenteDeDatosFalsa db;
  late OrdenesProvider ordenesProvider;
  late TallerProvider tallerProvider;

  setUp(() {
    db = FuenteDeDatosFalsa();
    ordenesProvider = OrdenesProvider(db: db);
    tallerProvider = TallerProvider(db: db);
    tallerProvider.setTaller(PerfilTaller(
      usuarioAdministradorId: 'admin',
      nombreTaller: 'JP.RACING.315',
      moneda: 'COP',
    ));
  });

  void movimiento(String tipo, double monto, String concepto) {
    db.caja.add(RegistroCaja(
      tipo: tipo,
      monto: monto,
      concepto: concepto,
      fecha: DateTime(2026, 8, 14, 10),
    ));
  }

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<OrdenesProvider>.value(value: ordenesProvider),
          ChangeNotifierProvider<TallerProvider>.value(value: tallerProvider),
        ],
        child: const MaterialApp(home: ContabilidadScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ingresos, gastos y ganancia salen de los movimientos reales',
      (tester) async {
    movimiento('ingreso', 250000, 'Pago de Orden #OT-00012');
    movimiento('ingreso', 100000, 'Abono Orden #OT-00013 (EFECTIVO)');
    movimiento('egreso', 95000, 'Compra de aceite');

    await montar(tester);

    expect(find.text(pesos(350000)), findsOneWidget); // ingresos
    expect(find.text(pesos(95000)), findsWidgets); // egresos
    expect(find.text(pesos(255000)), findsOneWidget); // ganancia
    expect(find.text('Pago de Orden #OT-00012'), findsOneWidget);
  });

  testWidgets('los ingresos llevan signo + y los egresos signo −',
      (tester) async {
    movimiento('ingreso', 250000, 'Pago de Orden #OT-00012');
    movimiento('egreso', 95000, 'Compra de aceite');

    await montar(tester);

    expect(find.text('+ ${pesos(250000)}'), findsOneWidget);
    expect(find.text('- ${pesos(95000)}'), findsOneWidget);
  });

  testWidgets('con la caja vacía no se inventa nada', (tester) async {
    // Hasta el 15/08/2026 esta pantalla fabricaba seis movimientos —medio
    // millón de pesos en conceptos falsos— cuando no había caja ni sesión de
    // Supabase, marcados solo con una etiqueta pequeña. Era el último resto de
    // los datos de demostración que se quitaron el 12/08 porque mentían. Un
    // dueño de taller abriendo sus cuentas no puede ver dinero que no existe.
    await montar(tester);

    expect(find.text('No hay transacciones registradas'), findsOneWidget);
    expect(find.text('VISTA DEMO'), findsNothing);
    expect(find.textContaining('Frenos y Motor'), findsNothing);
    expect(find.text(pesos(0)), findsWidgets,
        reason: 'ingresos, gastos y ganancia en cero, que es la verdad');
    expect(db.caja, isEmpty);
  });

  testWidgets('con un movimiento real solo se ve ese', (tester) async {
    movimiento('ingreso', 250000, 'Pago de Orden #OT-00012');
    await montar(tester);

    expect(find.text('Pago de Orden #OT-00012'), findsOneWidget);
    expect(find.textContaining('Frenos y Motor'), findsNothing);
    expect(find.text(pesos(250000)), findsWidgets);
  });

  testWidgets('un egreso manual entra en caja y baja la ganancia',
      (tester) async {
    movimiento('ingreso', 250000, 'Pago de Orden #OT-00012');
    await montar(tester);

    await tester.tap(find.text('Nuevo Movimiento'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Egreso'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Concepto'), 'Compra de herramientas');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto (\$)'), '60000');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(db.caja, hasLength(2));
    final nuevo = db.caja.last;
    expect(nuevo.tipo, 'egreso');
    expect(nuevo.monto, 60000);
    expect(nuevo.concepto, 'Compra de herramientas');

    expect(find.text(pesos(190000)), findsOneWidget); // ganancia
    expect(find.text('Egreso registrado en caja'), findsOneWidget);
  });

  testWidgets('un movimiento sin concepto o con monto cero no se guarda',
      (tester) async {
    await montar(tester);

    await tester.tap(find.text('Nuevo Movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Monto (\$)'), '0');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(db.caja, isEmpty);
    expect(find.text('Ingrese un concepto'), findsOneWidget);
    expect(find.text('Monto inválido'), findsOneWidget);
  });

  testWidgets('editar un movimiento cambia su monto y su concepto',
      (tester) async {
    movimiento('ingreso', 250000, 'Pago de Orden #OT-00012');
    await montar(tester);

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextField, 'Concepto'),
        'Pago de Orden #OT-00012 (corregido)');
    await tester.enterText(
        find.widgetWithText(TextField, 'Monto (\$)'), '275000');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(db.caja, hasLength(1), reason: 'edita, no duplica');
    expect(db.caja.single.monto, 275000);
    expect(db.caja.single.concepto, 'Pago de Orden #OT-00012 (corregido)');
    expect(find.text(pesos(275000)), findsWidgets);
  });

  testWidgets('cancelar la edición deja el movimiento como estaba',
      (tester) async {
    movimiento('ingreso', 250000, 'Pago de Orden #OT-00012');
    await montar(tester);

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Monto (\$)'), '999999');
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(db.caja.single.monto, 250000);
  });
}
