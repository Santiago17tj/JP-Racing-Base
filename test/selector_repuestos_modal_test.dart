import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'package:moto_taller_app/data/models/repuesto.dart';
import 'package:moto_taller_app/data/providers/inventario_provider.dart';
import 'package:moto_taller_app/ui/widgets/selector_repuestos_modal.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// El buscador de repuestos que se abre desde una orden.
///
/// Es la puerta por la que un repuesto entra en una factura: la cantidad que se
/// elija aquí es la que se le cobra al cliente y la que sale del inventario.
void main() {
  late FuenteDeDatosFalsa db;
  late InventarioProvider inventarioProvider;

  setUp(() {
    db = FuenteDeDatosFalsa();
    inventarioProvider = InventarioProvider(db: db);
  });

  Repuesto crearRepuesto({
    String nombre = 'Bomba de aceite nkd',
    String codigo = 'BOM-001',
    int stock = 10,
    double precioVenta = 120000,
  }) {
    final rep = Repuesto(
      codigoInterno: codigo,
      nombre: nombre,
      categoria: CategoriaRepuesto.otros,
      stockActual: stock,
      stockMinimo: 2,
      precioCosto: precioVenta / 2,
      precioVenta: precioVenta,
    );
    db.repuestos.add(rep);
    return rep;
  }

  /// Monta el modal y devuelve la lista de (repuesto, cantidad) seleccionados.
  Future<List<(Repuesto, int)>> montar(
    WidgetTester tester, {
    bool exito = true,
  }) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await inventarioProvider.cargarRepuestos();
    final elegidos = <(Repuesto, int)>[];

    // Se abre como hoja modal, igual que en la orden: al añadir un repuesto el
    // modal se cierra con `Navigator.pop()`, así que necesita una ruta propia
    // sobre la que hacerlo.
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SelectorRepuestosModal(
                    inventarioProvider: inventarioProvider,
                    onRepuestoSelected: (repuesto, cantidad) async {
                      elegidos.add((repuesto, cantidad));
                      return exito;
                    },
                  ),
                ),
                child: const Text('abrir selector'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir selector'));
    await tester.pumpAndSettle();
    return elegidos;
  }

  String pesos(double valor) => CurrencyFormatter.format(valor);

  testWidgets('lista los repuestos con su stock y su precio', (tester) async {
    crearRepuesto(stock: 10, precioVenta: 120000);
    await montar(tester);

    expect(find.text('Bomba de aceite nkd'), findsOneWidget);
    expect(
        find.text('SKU: BOM-001  |  Stock: 10  |  Precio: ${pesos(120000)}'),
        findsOneWidget);
  });

  testWidgets('con el inventario vacío lo dice', (tester) async {
    await montar(tester);

    expect(find.text('No hay repuestos activos en inventario'), findsOneWidget);
  });

  testWidgets('devuelve el repuesto con la cantidad elegida', (tester) async {
    final rep = crearRepuesto(stock: 10);
    final elegidos = await montar(tester);

    await tester.tap(find.byIcon(Icons.add)); // 1 → 2
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add)); // 2 → 3
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded)); // confirmar
    await tester.pumpAndSettle();

    expect(elegidos, hasLength(1));
    expect(elegidos.single.$1.id, rep.id);
    expect(elegidos.single.$2, 3);
    expect(find.text('Añadido: Bomba de aceite nkd'), findsOneWidget);
  });

  testWidgets('la cantidad no pasa del stock disponible', (tester) async {
    crearRepuesto(stock: 2);
    final elegidos = await montar(tester);

    await tester.tap(find.byIcon(Icons.add)); // 1 → 2, el tope
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add)); // no debe pasar de 2
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(elegidos.single.$2, 2);
  });

  testWidgets('la cantidad no baja de uno', (tester) async {
    crearRepuesto(stock: 10);
    final elegidos = await montar(tester);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(elegidos.single.$2, 1);
  });

  testWidgets('un repuesto sin stock se marca y no se puede añadir',
      (tester) async {
    crearRepuesto(stock: 0);
    final elegidos = await montar(tester);

    expect(find.text('SIN STOCK'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsNothing,
        reason: 'sin stock no hay botón para añadirlo');
    expect(elegidos, isEmpty);
  });

  testWidgets('si la orden rechaza el repuesto, el modal lo dice y no se cierra',
      (tester) async {
    crearRepuesto(stock: 10);
    final elegidos = await montar(tester, exito: false);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(elegidos, hasLength(1), reason: 'sí llegó a intentarlo');
    expect(find.text('Error al agregar (Verifica stock)'), findsOneWidget);
    expect(find.text('Bomba de aceite nkd'), findsOneWidget,
        reason: 'el modal sigue abierto para reintentar');
  });

  testWidgets('el buscador filtra la lista', (tester) async {
    crearRepuesto(nombre: 'Bomba de aceite nkd', codigo: 'BOM-001');
    crearRepuesto(nombre: 'Cadena 520', codigo: 'CAD-001');
    await montar(tester);

    await tester.enterText(find.byType(TextField), 'cadena');
    await tester.pumpAndSettle();

    expect(find.text('Cadena 520'), findsOneWidget);
    expect(find.text('Bomba de aceite nkd'), findsNothing);
  });
}
