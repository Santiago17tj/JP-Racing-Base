import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'package:moto_taller_app/data/models/historial_stock.dart';
import 'package:moto_taller_app/data/models/repuesto.dart';
import 'package:moto_taller_app/data/providers/inventario_provider.dart';
import 'package:moto_taller_app/data/providers/sesion_local_provider.dart';
import 'package:moto_taller_app/ui/screens/detalle_repuesto_sheet.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// Ficha de un repuesto con su historial de movimientos.
///
/// Muestra el precio de costo y el margen, que son información del dueño: en
/// modo mecánico tienen que desaparecer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FuenteDeDatosFalsa db;
  late InventarioProvider inventarioProvider;
  late SesionLocalProvider sesionProvider;
  late Repuesto repuesto;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FuenteDeDatosFalsa();
    inventarioProvider = InventarioProvider(db: db);
    sesionProvider = SesionLocalProvider();

    repuesto = Repuesto(
      codigoInterno: 'BOM-001',
      nombre: 'Bomba de aceite nkd',
      descripcion: 'Original AKT',
      marcaRepuesto: 'AKT',
      categoria: CategoriaRepuesto.motor,
      stockActual: 12,
      stockMinimo: 3,
      precioCosto: 60000,
      precioVenta: 120000,
    );
    db.repuestos.add(repuesto);
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
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
        child: MaterialApp(
          home: Scaffold(
            body: DetalleRepuestoSheet(
              repuesto: repuesto,
              provider: inventarioProvider,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String pesos(double valor) => CurrencyFormatter.format(valor);

  testWidgets('muestra nombre, código, marca y precio de venta',
      (tester) async {
    await montar(tester);

    expect(find.text('Bomba de aceite nkd'), findsOneWidget);
    expect(find.text('BOM-001'), findsOneWidget);
    expect(find.text('AKT'), findsOneWidget);
    expect(find.text('Original AKT'), findsOneWidget);
    expect(find.text(pesos(120000)), findsOneWidget);
  });

  testWidgets('el administrador ve el costo y el margen', (tester) async {
    await montar(tester);

    expect(find.text('COSTO'), findsOneWidget);
    expect(find.text(pesos(60000)), findsOneWidget);
    // (120.000 − 60.000) / 60.000 = 100 %
    expect(find.text('+100%'), findsOneWidget);
  });

  testWidgets('en modo mecánico desaparecen el costo y el margen',
      (tester) async {
    await sesionProvider.activarModoMecanico();
    await montar(tester);

    expect(find.text('COSTO'), findsNothing);
    expect(find.text(pesos(60000)), findsNothing);
    expect(find.text('MARGEN'), findsNothing);
    // El precio de venta sí lo necesita para atender al cliente.
    expect(find.text(pesos(120000)), findsOneWidget);
  });

  testWidgets('sin movimientos lo dice en vez de dejar el hueco',
      (tester) async {
    await montar(tester);

    expect(find.textContaining('movimiento'), findsWidgets);
    expect(db.historial, isEmpty);
  });

  testWidgets('lista los movimientos de stock del repuesto', (tester) async {
    db.historial.add(HistorialStock(
      repuestoId: repuesto.id,
      tipoMovimiento: TipoMovimiento.entrada,
      cantidad: 25,
      stockAnterior: 12,
      stockPosterior: 37,
      motivo: 'Compra a proveedor',
      createdAt: DateTime(2026, 8, 14, 10),
    ));
    db.historial.add(HistorialStock(
      repuestoId: repuesto.id,
      tipoMovimiento: TipoMovimiento.salida,
      cantidad: 2,
      stockAnterior: 37,
      stockPosterior: 35,
      motivo: 'Consumido en Orden de Mantenimiento',
      createdAt: DateTime(2026, 8, 14, 12),
    ));

    await montar(tester);

    expect(find.text('Compra a proveedor'), findsOneWidget);
    expect(find.text('Consumido en Orden de Mantenimiento'), findsOneWidget);
  });

  testWidgets('no mezcla el historial de otro repuesto', (tester) async {
    final otro = Repuesto(
      codigoInterno: 'CAD-001',
      nombre: 'Cadena 520',
      categoria: CategoriaRepuesto.otros,
      precioCosto: 40000,
      precioVenta: 95000,
    );
    db.repuestos.add(otro);
    db.historial.add(HistorialStock(
      repuestoId: otro.id,
      tipoMovimiento: TipoMovimiento.entrada,
      cantidad: 5,
      stockAnterior: 0,
      stockPosterior: 5,
      motivo: 'Movimiento de la cadena',
    ));

    await montar(tester);

    expect(find.text('Movimiento de la cadena'), findsNothing);
  });
}
