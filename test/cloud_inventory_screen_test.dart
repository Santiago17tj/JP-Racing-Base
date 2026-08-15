import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'package:moto_taller_app/data/models/repuesto.dart';
import 'package:moto_taller_app/data/providers/inventario_provider.dart';
import 'package:moto_taller_app/ui/screens/cloud_inventory_screen.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// La pestaña «Cloud»: el mismo inventario, en formato de fichas con foto.
void main() {
  late FuenteDeDatosFalsa db;
  late InventarioProvider inventarioProvider;

  setUp(() {
    db = FuenteDeDatosFalsa();
    inventarioProvider = InventarioProvider(db: db);
  });

  void crearRepuesto({
    String nombre = 'Bomba de aceite nkd',
    String codigo = 'BOM-001',
    int stock = 10,
    double precioVenta = 120000,
  }) {
    db.repuestos.add(Repuesto(
      codigoInterno: codigo,
      nombre: nombre,
      categoria: CategoriaRepuesto.otros,
      stockActual: stock,
      stockMinimo: 2,
      precioCosto: precioVenta / 2,
      precioVenta: precioVenta,
    ));
  }

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<InventarioProvider>.value(
        value: inventarioProvider,
        child: const MaterialApp(home: CloudInventoryScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('lista los repuestos con su precio', (tester) async {
    crearRepuesto(precioVenta: 120000);
    await montar(tester);

    expect(find.text('Bomba de aceite nkd'), findsOneWidget);
    expect(find.text('Precio: ${CurrencyFormatter.format(120000)}'),
        findsOneWidget);
    expect(find.text('Stock: 10'), findsOneWidget);
  });

  testWidgets('con el inventario vacío no revienta ni inventa filas',
      (tester) async {
    await montar(tester);

    expect(find.byType(CloudInventoryScreen), findsOneWidget);
    expect(find.text('Bomba de aceite nkd'), findsNothing);
  });

  testWidgets('muestra todos los repuestos activos', (tester) async {
    crearRepuesto(nombre: 'Bomba de aceite nkd', codigo: 'BOM-001');
    crearRepuesto(nombre: 'Cadena 520', codigo: 'CAD-001');
    await montar(tester);

    expect(find.text('Bomba de aceite nkd'), findsOneWidget);
    expect(find.text('Cadena 520'), findsOneWidget);
  });

  testWidgets('el botón de refrescar vuelve a pedir la lista', (tester) async {
    crearRepuesto();
    await montar(tester);
    final antes = db.llamadas['getRepuestos'] ?? 0;

    await tester.tap(find.byIcon(Icons.refresh_rounded));
    await tester.pumpAndSettle();

    expect(db.llamadas['getRepuestos'], greaterThan(antes));
  });

  testWidgets('ofrece crear un repuesto nuevo', (tester) async {
    await montar(tester);

    expect(find.text('Nuevo repuesto'), findsOneWidget);
  });
}
