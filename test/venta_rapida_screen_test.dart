import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'package:moto_taller_app/data/models/repuesto.dart';
import 'package:moto_taller_app/data/providers/inventario_provider.dart';
import 'package:moto_taller_app/data/providers/ordenes_provider.dart';
import 'package:moto_taller_app/data/providers/sesion_local_provider.dart';
import 'package:moto_taller_app/ui/screens/venta_rapida_screen.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// Venta de mostrador: se cobra en el momento y sale del inventario.
///
/// Aquí el dinero y el stock se mueven en la misma operación, así que un fallo
/// descuadra las dos cosas a la vez.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FuenteDeDatosFalsa db;
  late OrdenesProvider ordenesProvider;
  late InventarioProvider inventarioProvider;
  late SesionLocalProvider sesionProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FuenteDeDatosFalsa();
    ordenesProvider = OrdenesProvider(db: db);
    inventarioProvider = InventarioProvider(db: db);
    sesionProvider = SesionLocalProvider();
  });

  Repuesto crearRepuesto({
    String nombre = 'Bomba de aceite nkd',
    String codigo = 'BOM-001',
    int stock = 10,
    double precioVenta = 120000,
    double precioCosto = 70000,
  }) {
    final rep = Repuesto(
      codigoInterno: codigo,
      nombre: nombre,
      categoria: CategoriaRepuesto.otros,
      stockActual: stock,
      stockMinimo: 2,
      precioCosto: precioCosto,
      precioVenta: precioVenta,
    );
    db.repuestos.add(rep);
    return rep;
  }

  /// Monta la disposición de **teléfono** (< 700 px de ancho), que es la que
  /// usa el taller.
  ///
  /// **Estas pruebas no dicen nada de cómo se ve la pantalla.** En
  /// `flutter_test` la fuente por defecto dibuja cada carácter como un cuadrado
  /// del alto de la letra: «REGISTRAR VENTA (PAGADA)» ocupa 374 px cuando con
  /// la fuente real ronda los 226. Por eso el ancho de aquí (690) está elegido
  /// para que quepa esa fuente falsa, no para imitar un teléfono — un móvil de
  /// verdad tiene 360-430 px. Lo que se comprueba es el contenido y el
  /// comportamiento; los desbordamientos que salgan a este ancho serían del
  /// tipo de letra de la prueba, no de la app. Para cubrir de verdad la
  /// disposición habría que cargar antes una fuente real.
  Future<void> montar(WidgetTester tester,
      {Size tamano = const Size(690, 1600)}) async {
    tester.view.physicalSize = tamano;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<OrdenesProvider>.value(value: ordenesProvider),
          ChangeNotifierProvider<InventarioProvider>.value(
              value: inventarioProvider),
          ChangeNotifierProvider<SesionLocalProvider>.value(
              value: sesionProvider),
        ],
        child: const MaterialApp(home: VentaRapidaScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Busca un repuesto por nombre y lo mete al carrito.
  Future<void> agregarAlCarrito(WidgetTester tester, String nombre) async {
    await tester.enterText(find.byType(TextField).first, nombre);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, nombre));
    await tester.pumpAndSettle();
  }

  String pesos(double valor) => CurrencyFormatter.format(valor);

  testWidgets('el carrito empieza vacío y el botón de cobro apagado',
      (tester) async {
    crearRepuesto();
    await montar(tester);

    expect(find.text('El carrito está vacío'), findsOneWidget);
    final boton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'REGISTRAR VENTA (PAGADA)'));
    expect(boton.onPressed, isNull);
  });

  testWidgets('buscar un repuesto y añadirlo calcula el total', (tester) async {
    crearRepuesto(precioVenta: 120000);
    await montar(tester);

    await agregarAlCarrito(tester, 'Bomba de aceite nkd');

    expect(find.text('1 u.'), findsOneWidget);
    expect(find.text(pesos(120000)), findsWidgets);

    // Dos unidades más: 3 × 120.000.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    expect(find.text('3 u.'), findsOneWidget);
    expect(find.text(pesos(360000)), findsWidgets);
  });

  testWidgets('no deja vender más unidades de las que hay en stock',
      (tester) async {
    crearRepuesto(stock: 2, precioVenta: 120000);
    await montar(tester);

    await agregarAlCarrito(tester, 'Bomba de aceite nkd');
    await tester.tap(find.byIcon(Icons.add)); // 2, el tope
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add)); // se pasa
    await tester.pumpAndSettle();

    expect(find.text('2 u.'), findsOneWidget);
    expect(find.textContaining('Límite de stock alcanzado'), findsOneWidget);
  });

  testWidgets('un repuesto sin stock no se puede añadir', (tester) async {
    crearRepuesto(stock: 0);
    await montar(tester);

    await tester.enterText(find.byType(TextField).first, 'Bomba');
    await tester.pumpAndSettle();

    final tile =
        tester.widget<ListTile>(find.widgetWithText(ListTile, 'Bomba de aceite nkd'));
    expect(tile.onTap, isNull, reason: 'sin stock no debe poder tocarse');
    expect(find.text('El carrito está vacío'), findsOneWidget);
  });

  testWidgets('cobrar descuenta el stock y registra el ingreso en caja',
      (tester) async {
    final rep = crearRepuesto(stock: 10, precioVenta: 120000);
    await montar(tester);

    await agregarAlCarrito(tester, 'Bomba de aceite nkd');
    await tester.tap(find.byIcon(Icons.add)); // 2 unidades
    await tester.pumpAndSettle();

    await tester.tap(find.text('REGISTRAR VENTA (PAGADA)'));
    await tester.pumpAndSettle();

    expect(db.repuestoPorId(rep.id).stockActual, 8);
    expect(db.caja, hasLength(1));
    expect(db.caja.single.tipo, 'ingreso');
    expect(db.caja.single.monto, 240000);
    expect(db.caja.single.concepto, contains('Venta rápida'));
    expect(db.caja.single.concepto, contains('2 items'));

    expect(find.text('¡Venta Exitosa!'), findsOneWidget);
    expect(find.text('Total Cobrado: ${pesos(240000)}'), findsOneWidget);
  });

  testWidgets('la ganancia estimada descuenta el costo', (tester) async {
    crearRepuesto(precioVenta: 120000, precioCosto: 70000);
    await montar(tester);

    await agregarAlCarrito(tester, 'Bomba de aceite nkd');

    expect(find.text('Valor del Costo'), findsOneWidget);
    expect(find.text(pesos(70000)), findsOneWidget);
    expect(find.text('+${pesos(50000)}'), findsOneWidget);
  });

  testWidgets('en modo mecánico no se ven el costo ni la ganancia',
      (tester) async {
    // El bloqueo es de interfaz, no de seguridad, pero su razón de ser es que
    // el mecánico no vea los márgenes del dueño. Si deja de ocultarlos, deja
    // de servir para nada.
    crearRepuesto(precioVenta: 120000, precioCosto: 70000);
    await sesionProvider.activarModoMecanico();
    await montar(tester);

    await agregarAlCarrito(tester, 'Bomba de aceite nkd');

    expect(find.text('Valor del Costo'), findsNothing);
    expect(find.text(pesos(70000)), findsNothing);
    expect(find.text('Ganancia neta estimada'), findsNothing);
    // Lo que sí debe ver: qué cobrar.
    expect(find.text('TOTAL COBRAR'), findsOneWidget);
    expect(find.text(pesos(120000)), findsWidgets);
  });

  testWidgets('bajar la cantidad a cero saca el repuesto del carrito',
      (tester) async {
    crearRepuesto();
    await montar(tester);

    await agregarAlCarrito(tester, 'Bomba de aceite nkd');
    expect(find.text('El carrito está vacío'), findsNothing);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();

    expect(find.text('El carrito está vacío'), findsOneWidget);
    expect(db.caja, isEmpty);
  });

  testWidgets('una búsqueda sin resultados lo dice', (tester) async {
    crearRepuesto();
    await montar(tester);

    await tester.enterText(find.byType(TextField).first, 'kryptonita');
    await tester.pumpAndSettle();

    expect(find.text('Ningún repuesto coincide con la búsqueda.'),
        findsOneWidget);
  });
}
