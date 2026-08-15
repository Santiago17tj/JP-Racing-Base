import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'package:moto_taller_app/data/models/repuesto.dart';
import 'package:moto_taller_app/data/providers/inventario_provider.dart';
import 'package:moto_taller_app/data/providers/sesion_local_provider.dart';
import 'package:moto_taller_app/ui/screens/inventario_screen.dart';
import 'package:moto_taller_app/ui/widgets/category_filter.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// El inventario: buscar, filtrar y mover stock a mano.
///
/// El stock es dinero: cada unidad que se pierde o se duplica aquí descuadra el
/// valor del inventario y, cuando ese repuesto entre en una orden, la factura.
///
/// Como en las demás pruebas de pantalla, el tamaño de la ventana está puesto
/// para que quepa la fuente de `flutter_test`; no dicen nada de cómo se ve.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FuenteDeDatosFalsa db;
  late InventarioProvider inventarioProvider;
  late SesionLocalProvider sesionProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FuenteDeDatosFalsa();
    inventarioProvider = InventarioProvider(db: db);
    sesionProvider = SesionLocalProvider();
  });

  Repuesto crearRepuesto({
    required String nombre,
    required String codigo,
    int stock = 10,
    int stockMinimo = 2,
    double precioVenta = 120000,
    double precioCosto = 70000,
    CategoriaRepuesto categoria = CategoriaRepuesto.otros,
  }) {
    final rep = Repuesto(
      codigoInterno: codigo,
      nombre: nombre,
      categoria: categoria,
      stockActual: stock,
      stockMinimo: stockMinimo,
      precioCosto: precioCosto,
      precioVenta: precioVenta,
    );
    db.repuestos.add(rep);
    return rep;
  }

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<InventarioProvider>.value(
              value: inventarioProvider),
          ChangeNotifierProvider<SesionLocalProvider>.value(
              value: sesionProvider),
        ],
        child: const MaterialApp(home: InventarioScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  String pesos(double valor) => CurrencyFormatter.format(valor);

  group('resumen de arriba', () {
    testWidgets('cuenta los repuestos y suma el valor del inventario',
        (tester) async {
      crearRepuesto(nombre: 'Bomba de aceite', codigo: 'BOM-001', stock: 10, precioVenta: 120000);
      crearRepuesto(nombre: 'Cadena 520', codigo: 'CAD-001', stock: 4, precioVenta: 95000);
      await montar(tester);

      expect(find.text('2'), findsWidgets); // total repuestos
      // 10 × 120.000 + 4 × 95.000 = 1.580.000
      expect(find.text(pesos(1580000)), findsOneWidget);
    });

    testWidgets('avisa de los repuestos bajo mínimo', (tester) async {
      crearRepuesto(nombre: 'Bomba de aceite', codigo: 'BOM-001', stock: 10, stockMinimo: 2);
      crearRepuesto(nombre: 'Cadena 520', codigo: 'CAD-001', stock: 1, stockMinimo: 5);
      await montar(tester);

      expect(find.text('1 en revisión'), findsOneWidget);
    });

    testWidgets('sin repuestos bajo mínimo dice que el stock está estable',
        (tester) async {
      crearRepuesto(nombre: 'Bomba de aceite', codigo: 'BOM-001', stock: 10, stockMinimo: 2);
      await montar(tester);

      expect(find.text('Stock estable'), findsOneWidget);
    });

    testWidgets('cuenta los repuestos sin stock', (tester) async {
      crearRepuesto(nombre: 'Bomba de aceite', codigo: 'BOM-001', stock: 0);
      crearRepuesto(nombre: 'Cadena 520', codigo: 'CAD-001', stock: 4);
      await montar(tester);

      expect(find.text('SIN STOCK'), findsOneWidget);
    });
  });

  group('buscar y filtrar', () {
    testWidgets('la búsqueda filtra por nombre', (tester) async {
      crearRepuesto(nombre: 'Bomba de aceite', codigo: 'BOM-001');
      crearRepuesto(nombre: 'Cadena 520', codigo: 'CAD-001');
      await montar(tester);

      await tester.enterText(find.byType(TextField).first, 'cadena');
      await tester.pumpAndSettle();

      expect(find.text('Cadena 520'), findsOneWidget);
      expect(find.text('Bomba de aceite'), findsNothing);
    });

    testWidgets('la búsqueda también sirve con el código interno',
        (tester) async {
      crearRepuesto(nombre: 'Bomba de aceite', codigo: 'BOM-001');
      crearRepuesto(nombre: 'Cadena 520', codigo: 'CAD-001');
      await montar(tester);

      await tester.enterText(find.byType(TextField).first, 'BOM-001');
      await tester.pumpAndSettle();

      expect(find.text('Bomba de aceite'), findsOneWidget);
      expect(find.text('Cadena 520'), findsNothing);
    });

    testWidgets('sin coincidencias ofrece limpiar los filtros', (tester) async {
      crearRepuesto(nombre: 'Bomba de aceite', codigo: 'BOM-001');
      await montar(tester);

      await tester.enterText(find.byType(TextField).first, 'kryptonita');
      await tester.pumpAndSettle();

      expect(find.text('No se encontraron repuestos'), findsOneWidget);
      expect(find.text('Limpiar filtros'), findsOneWidget);

      await tester.tap(find.text('Limpiar filtros'));
      await tester.pumpAndSettle();

      expect(find.text('Bomba de aceite'), findsOneWidget);
    });

    testWidgets('el filtro de stock bajo deja solo los que están por debajo',
        (tester) async {
      crearRepuesto(nombre: 'Bomba de aceite', codigo: 'BOM-001', stock: 10, stockMinimo: 2);
      crearRepuesto(nombre: 'Cadena 520', codigo: 'CAD-001', stock: 1, stockMinimo: 5);
      await montar(tester);

      await tester.tap(find.text('Stock Bajo'));
      await tester.pumpAndSettle();

      expect(find.text('Cadena 520'), findsOneWidget);
      expect(find.text('Bomba de aceite'), findsNothing);
    });

    testWidgets('el filtro por categoría se activa y se quita al repetirlo',
        (tester) async {
      crearRepuesto(
          nombre: 'Bomba de aceite',
          codigo: 'BOM-001',
          categoria: CategoriaRepuesto.motor);
      crearRepuesto(
          nombre: 'Cadena 520',
          codigo: 'CAD-001',
          categoria: CategoriaRepuesto.otros);
      await montar(tester);

      // El nombre de la categoría sale dos veces: en el chip del filtro y en
      // la tarjeta del repuesto. Hay que apuntar al chip.
      final chipMotor = find.descendant(
        of: find.byType(CategoryFilter),
        matching: find.text(CategoriaRepuesto.motor.label),
      );

      await tester.tap(chipMotor);
      await tester.pumpAndSettle();
      expect(find.text('Bomba de aceite'), findsOneWidget);
      expect(find.text('Cadena 520'), findsNothing);

      // Volver a tocarlo lo desactiva.
      await tester.tap(chipMotor);
      await tester.pumpAndSettle();
      expect(find.text('Cadena 520'), findsOneWidget);
    });
  });

  group('mover stock desde la tarjeta', () {
    testWidgets('el + y el − suben y bajan una unidad', (tester) async {
      final rep = crearRepuesto(nombre: 'Bomba de aceite', codigo: 'BOM-001', stock: 10);
      await montar(tester);

      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();
      expect(db.repuestoPorId(rep.id).stockActual, 11);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();
      expect(db.repuestoPorId(rep.id).stockActual, 10);
    });

    testWidgets('el − está apagado cuando ya no queda stock', (tester) async {
      crearRepuesto(nombre: 'Bomba de aceite', codigo: 'BOM-001', stock: 0);
      await montar(tester);

      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pumpAndSettle();

      expect(db.repuestos.single.stockActual, 0,
          reason: 'no debe bajar de cero desde la tarjeta');
    });

    testWidgets('el ajuste manual de entrada suma y deja el motivo escrito',
        (tester) async {
      final rep = crearRepuesto(nombre: 'Bomba de aceite', codigo: 'BOM-001', stock: 10);
      await montar(tester);

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextField, 'Cantidad'), '25');
      await tester.enterText(find.widgetWithText(TextField, 'Motivo (opcional)'),
          'Compra a proveedor');
      await tester.tap(find.text('APLICAR ENTRADA'));
      await tester.pumpAndSettle();

      expect(db.repuestoPorId(rep.id).stockActual, 35);
      final movimiento = db.historial.last;
      expect(movimiento.cantidad, 25);
      expect(movimiento.tipoMovimiento, TipoMovimiento.entrada);
      expect(movimiento.motivo, 'Compra a proveedor');
      expect(movimiento.stockAnterior, 10);
      expect(movimiento.stockPosterior, 35);
    });

    testWidgets('el ajuste manual de salida resta', (tester) async {
      final rep = crearRepuesto(nombre: 'Bomba de aceite', codigo: 'BOM-001', stock: 10);
      await montar(tester);

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('SALIDA'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '3');
      await tester.tap(find.text('APLICAR SALIDA'));
      await tester.pumpAndSettle();

      expect(db.repuestoPorId(rep.id).stockActual, 7);
      expect(db.historial.last.tipoMovimiento, TipoMovimiento.salida);
      expect(db.historial.last.motivo, 'Salida / ajuste manual');
    });

    testWidgets('un ajuste de cero no mueve nada', (tester) async {
      final rep = crearRepuesto(nombre: 'Bomba de aceite', codigo: 'BOM-001', stock: 10);
      await montar(tester);

      await tester.tap(find.byIcon(Icons.tune_rounded));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Cantidad'), '0');
      await tester.tap(find.text('APLICAR ENTRADA'));
      await tester.pumpAndSettle();

      expect(db.repuestoPorId(rep.id).stockActual, 10);
      expect(db.historial, isEmpty);
    });
  });
}
