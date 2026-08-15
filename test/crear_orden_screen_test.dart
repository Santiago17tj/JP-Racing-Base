import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/data/models/cliente.dart';
import 'package:moto_taller_app/data/models/vehiculo.dart';
import 'package:moto_taller_app/data/providers/ordenes_provider.dart';
import 'package:moto_taller_app/ui/screens/crear_orden_screen.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// El check-in de la moto: aquí nace la orden y, con ella, el folio.
///
/// Es la pantalla donde el taller del cliente estuvo meses fallando en
/// silencio — todas sus órdenes salían con el mismo OT-00001 y ninguna llegaba
/// a la nube.
///
/// Sobre el ancho de la ventana: `flutter_test` dibuja cada carácter como un
/// cuadrado del alto de la letra, mucho más ancho que la fuente real, así que
/// el tamaño de aquí está elegido para que quepa esa fuente falsa. **Estas
/// pruebas no dicen nada de cómo se ve la pantalla**, solo de qué se guarda.
void main() {
  late FuenteDeDatosFalsa db;
  late OrdenesProvider ordenesProvider;

  setUp(() {
    db = FuenteDeDatosFalsa();
    ordenesProvider = OrdenesProvider(db: db);
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ordenesProvider.cargarDatos();

    await tester.pumpWidget(
      ChangeNotifierProvider<OrdenesProvider>.value(
        value: ordenesProvider,
        child: MaterialApp(
          // Se abre empujada sobre otra ruta porque al guardar hace `pop`:
          // si fuera la ruta raíz, volver no tendría a dónde.
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CrearOrdenScreen()),
                  ),
                  child: const Text('abrir check-in'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir check-in'));
    await tester.pumpAndSettle();
  }

  Future<void> escribir(
      WidgetTester tester, String etiqueta, String valor) async {
    await tester.enterText(
        find.widgetWithText(TextFormField, etiqueta), valor);
    await tester.pump();
  }

  /// Rellena todo lo obligatorio de un cliente nuevo con su moto.
  Future<void> rellenarClienteNuevo(WidgetTester tester) async {
    await escribir(tester, 'Nombre', 'Johan');
    await escribir(tester, 'Apellido', 'Parada');
    await escribir(tester, 'Nº Documento', '1098765432');
    await escribir(tester, 'Teléfono', '3150000000');
    await escribir(tester, 'Placa / Patente', 'cla87a');
    await escribir(tester, 'Marca', 'AKT');
    await escribir(tester, 'Modelo', 'NKD 125');
    await escribir(tester, 'Año', '2020');
    await escribir(tester, 'Kilometraje de Ingreso', '15000');
    await escribir(tester, 'Mecánico Responsable', 'Luis');
    await escribir(tester, 'Problema que reporta el cliente', 'Suena la cadena');
  }

  Future<void> guardar(WidgetTester tester) async {
    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    final boton = find.descendant(
      of: find.byType(CrearOrdenScreen),
      matching: find.byType(ElevatedButton),
    );
    await tester.ensureVisible(boton.last);
    await tester.pumpAndSettle();
    await tester.tap(boton.last);
    await tester.pumpAndSettle();
  }

  testWidgets('un cliente nuevo crea cliente, moto y orden', (tester) async {
    await montar(tester);
    await rellenarClienteNuevo(tester);
    await guardar(tester);

    expect(db.clientes, hasLength(1));
    expect(db.vehiculos, hasLength(1));
    expect(db.ordenes, hasLength(1));

    final cliente = db.clientes.single;
    expect(cliente.nombre, 'Johan');
    expect(cliente.numeroDocumento, '1098765432');

    final moto = db.vehiculos.single;
    expect(moto.placaPatente, 'CLA87A', reason: 'la placa se guarda en mayúsculas');
    expect(moto.clienteId, cliente.id);

    final orden = db.ordenes.single;
    expect(orden.numeroOrden, 'OT-00001');
    expect(orden.clienteId, cliente.id);
    expect(orden.vehiculoId, moto.id);
    expect(orden.estado, EstadoOrden.ingresada);
    expect(orden.mecanicoAsignado, 'Luis');
    expect(orden.kilometrajeIngreso, 15000);
    expect(orden.esCotizacion, isFalse);
    expect(orden.tipoServicio, TiposServicio.preventivo);
  });

  testWidgets('el folio de la segunda orden no repite el de la primera',
      (tester) async {
    // Aquí estuvo el bug que dejó al taller del cliente con 0 órdenes en la
    // nube: dos órdenes distintas numeradas OT-00001.
    await montar(tester);
    await rellenarClienteNuevo(tester);
    await guardar(tester);

    await tester.tap(find.text('abrir check-in'));
    await tester.pumpAndSettle();
    await rellenarClienteNuevo(tester);
    await escribir(tester, 'Nº Documento', '1098765433');
    await escribir(tester, 'Placa / Patente', 'xyz12b');
    await guardar(tester);

    expect(db.ordenes, hasLength(2));
    expect(db.ordenes.map((o) => o.numeroOrden).toSet(), hasLength(2));
  });

  testWidgets('con el formulario vacío no se guarda nada', (tester) async {
    await montar(tester);
    await guardar(tester);

    expect(db.clientes, isEmpty);
    expect(db.vehiculos, isEmpty);
    expect(db.ordenes, isEmpty);
    expect(find.text('Requerido'), findsWidgets);
    expect(find.byType(CrearOrdenScreen), findsOneWidget,
        reason: 'no debe cerrarse si no guardó');
  });

  testWidgets('marcar cotización la guarda como tal y cambia el título',
      (tester) async {
    await montar(tester);
    await rellenarClienteNuevo(tester);

    await tester.ensureVisible(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(find.text('Nueva Cotización'), findsOneWidget);

    await guardar(tester);
    expect(db.ordenes.single.esCotizacion, isTrue);
  });

  testWidgets('con «Otro» servicio se guarda lo que escribió el mecánico',
      (tester) async {
    await montar(tester);
    await rellenarClienteNuevo(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TiposServicio.otro).last);
    await tester.pumpAndSettle();

    await escribir(
        tester, 'Escribir servicio personalizado', 'Rectificada de cilindro');
    await guardar(tester);

    expect(db.ordenes.single.tipoServicio, 'Rectificada de cilindro');
  });

  testWidgets('«Otro» sin escribir el servicio no deja guardar', (tester) async {
    await montar(tester);
    await rellenarClienteNuevo(tester);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TiposServicio.otro).last);
    await tester.pumpAndSettle();
    await guardar(tester);

    expect(db.ordenes, isEmpty);
    expect(find.text('Requerido'), findsWidgets);
  });

  testWidgets('un cliente existente reutiliza su moto y su kilometraje',
      (tester) async {
    final cliente = Cliente(
      nombre: 'Johan',
      apellido: 'Parada',
      tipoDocumento: TipoDocumento.cc,
      numeroDocumento: '1098765432',
      telefono: '3150000000',
    );
    final moto = Vehiculo(
      clienteId: cliente.id,
      placaPatente: 'CLA87A',
      marca: 'AKT',
      modelo: 'NKD 125',
      anio: 2020,
      kilometrajeActual: 22000,
    );
    db.clientes.add(cliente);
    db.vehiculos.add(moto);

    await montar(tester);
    await tester.tap(find.text('Cliente Existente'));
    await tester.pumpAndSettle();

    expect(find.text('AKT NKD 125 [CLA87A]'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(
              find.widgetWithText(TextFormField, 'Kilometraje de Ingreso'))
          .controller
          ?.text,
      '22000',
      reason: 'se propone el kilometraje que ya tenía la moto',
    );

    await escribir(tester, 'Kilometraje de Ingreso', '23500');
    await escribir(tester, 'Mecánico Responsable', 'Luis');
    await escribir(tester, 'Problema que reporta el cliente', 'Frenos');
    await guardar(tester);

    expect(db.clientes, hasLength(1), reason: 'no duplica el cliente');
    expect(db.vehiculos, hasLength(1), reason: 'no duplica la moto');
    expect(db.ordenes.single.clienteId, cliente.id);
    expect(db.ordenes.single.vehiculoId, moto.id);
    expect(db.ordenes.single.kilometrajeIngreso, 23500);
  });

  testWidgets('sin clientes registrados lo dice en vez de dejar el hueco',
      (tester) async {
    await montar(tester);
    await tester.tap(find.text('Cliente Existente'));
    await tester.pumpAndSettle();

    expect(find.text('No hay clientes registrados.'), findsOneWidget);
  });

  testWidgets('el dígito de verificación solo aparece con NIT', (tester) async {
    await montar(tester);
    await escribir(tester, 'Nº Documento', '900373115');
    expect(find.textContaining('DV:'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<TipoDocumento>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NIT').last);
    await tester.pumpAndSettle();

    expect(find.text('DV: ${Cliente.calcularDV('900373115')}'), findsOneWidget);
  });
}
