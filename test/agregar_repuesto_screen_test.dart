import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/data/models/repuesto.dart';
import 'package:moto_taller_app/data/providers/inventario_provider.dart';
import 'package:moto_taller_app/ui/screens/agregar_repuesto_screen.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// Alta y edición de repuestos. Aquí se fijan **los dos precios**: el de costo,
/// del que sale el margen, y el de venta, que es lo que acaba en la factura.
///
/// El tamaño de la ventana está puesto para que quepa la fuente de
/// `flutter_test`; estas pruebas no dicen nada de cómo se ve la pantalla.
void main() {
  late FuenteDeDatosFalsa db;
  late InventarioProvider inventarioProvider;

  setUp(() {
    db = FuenteDeDatosFalsa();
    inventarioProvider = InventarioProvider(db: db);
  });

  Future<void> montar(WidgetTester tester, {Repuesto? aEditar}) async {
    tester.view.physicalSize = const Size(1100, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<InventarioProvider>.value(
        value: inventarioProvider,
        child: MaterialApp(
          // Empujada sobre otra ruta: al guardar hace `pop(true)`.
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AgregarRepuestoScreen(repuestoAEditar: aEditar),
                    ),
                  ),
                  child: const Text('abrir formulario'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir formulario'));
    await tester.pumpAndSettle();
  }

  Future<void> escribir(
      WidgetTester tester, String etiqueta, String valor) async {
    await tester.enterText(
        find.widgetWithText(TextFormField, etiqueta), valor);
    await tester.pump();
  }

  Future<void> guardar(WidgetTester tester, String etiquetaBoton) async {
    final boton = find.widgetWithText(ElevatedButton, etiquetaBoton);
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();
  }

  group('crear', () {
    testWidgets('un repuesto nuevo se guarda con sus precios y su stock',
        (tester) async {
      await montar(tester);
      expect(find.text('Nuevo Repuesto'), findsOneWidget);

      await escribir(tester, 'Código Interno (SKU) *', 'BOM-001');
      await escribir(tester, 'Nombre del repuesto *', 'Bomba de aceite nkd');
      await escribir(tester, 'Descripción', 'Original AKT');
      await escribir(tester, 'Stock actual', '12');
      await escribir(tester, 'Stock mínimo', '3');
      await escribir(tester, 'Precio costo', '70000');
      await escribir(tester, 'Precio venta', '120000');
      await guardar(tester, 'CREAR REPUESTO');

      expect(db.repuestos, hasLength(1));
      final rep = db.repuestos.single;
      expect(rep.codigoInterno, 'BOM-001');
      expect(rep.nombre, 'Bomba de aceite nkd');
      expect(rep.descripcion, 'Original AKT');
      expect(rep.stockActual, 12);
      expect(rep.stockMinimo, 3);
      expect(rep.precioCosto, 70000);
      expect(rep.precioVenta, 120000);
      expect(rep.activo, isTrue);
    });

    testWidgets('sin código ni nombre no se guarda', (tester) async {
      await montar(tester);
      await guardar(tester, 'CREAR REPUESTO');

      expect(db.repuestos, isEmpty);
      expect(find.text('El código es requerido'), findsOneWidget);
      expect(find.text('El nombre es requerido'), findsOneWidget);
    });

    testWidgets('los precios en blanco quedan en cero, no en nulo',
        (tester) async {
      await montar(tester);
      await escribir(tester, 'Código Interno (SKU) *', 'BOM-001');
      await escribir(tester, 'Nombre del repuesto *', 'Bomba de aceite');
      await escribir(tester, 'Precio costo', '');
      await escribir(tester, 'Precio venta', '');
      await guardar(tester, 'CREAR REPUESTO');

      expect(db.repuestos.single.precioCosto, 0);
      expect(db.repuestos.single.precioVenta, 0);
    });

    testWidgets('el stock no admite letras ni signos', (tester) async {
      await montar(tester);
      await escribir(tester, 'Stock actual', '-5a2');

      expect(
        tester
            .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'Stock actual'))
            .controller
            ?.text,
        '52',
        reason: 'el campo solo deja dígitos',
      );
    });

    testWidgets('la categoría elegida se guarda', (tester) async {
      await montar(tester);
      await escribir(tester, 'Código Interno (SKU) *', 'MOT-001');
      await escribir(tester, 'Nombre del repuesto *', 'Pistón');

      await tester.tap(find.byType(DropdownButtonFormField<CategoriaRepuesto>));
      await tester.pumpAndSettle();
      await tester
          .tap(find
              .text('${CategoriaRepuesto.motor.icon}  ${CategoriaRepuesto.motor.label}')
              .last);
      await tester.pumpAndSettle();
      await guardar(tester, 'CREAR REPUESTO');

      expect(db.repuestos.single.categoria, CategoriaRepuesto.motor);
    });
  });

  group('editar', () {
    Repuesto repuestoExistente() {
      final rep = Repuesto(
        codigoInterno: 'BOM-001',
        nombre: 'Bomba de aceite nkd',
        categoria: CategoriaRepuesto.motor,
        stockActual: 12,
        stockMinimo: 3,
        precioCosto: 70000,
        precioVenta: 120000,
      );
      db.repuestos.add(rep);
      return rep;
    }

    testWidgets('abre con los datos del repuesto ya escritos', (tester) async {
      final rep = repuestoExistente();
      await montar(tester, aEditar: rep);

      expect(find.text('Editar Repuesto'), findsOneWidget);
      expect(find.text('BOM-001'), findsOneWidget);
      expect(find.text('Bomba de aceite nkd'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('120000.00'), findsOneWidget);
    });

    testWidgets('cambiar el precio de venta no crea un repuesto nuevo',
        (tester) async {
      final rep = repuestoExistente();
      await montar(tester, aEditar: rep);

      await escribir(tester, 'Precio venta', '135000');
      await guardar(tester, 'GUARDAR CAMBIOS');

      expect(db.repuestos, hasLength(1), reason: 'edita, no duplica');
      expect(db.repuestoPorId(rep.id).precioVenta, 135000);
      expect(db.repuestoPorId(rep.id).id, rep.id,
          reason: 'el id no cambia; si cambiara, la nube lo vería como otro');
    });

    testWidgets('un precio con letras conserva el que ya tenía',
        (tester) async {
      // El campo filtra la entrada, pero si algo se colara, `double.tryParse`
      // devuelve nulo y el código cae al valor anterior en vez de poner 0. Un
      // repuesto con precio 0 se factura gratis.
      final rep = repuestoExistente();
      await montar(tester, aEditar: rep);

      await escribir(tester, 'Precio venta', '');
      await guardar(tester, 'GUARDAR CAMBIOS');

      expect(db.repuestoPorId(rep.id).precioVenta, 120000);
    });

    testWidgets('en modo edición no se ofrece foto', (tester) async {
      final rep = repuestoExistente();
      await montar(tester, aEditar: rep);

      expect(find.text('Seleccionar foto'), findsNothing);
    });
  });
}
