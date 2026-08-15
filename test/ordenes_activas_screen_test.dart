import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/data/models/cliente.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/data/models/vehiculo.dart';
import 'package:moto_taller_app/data/providers/ordenes_provider.dart';
import 'package:moto_taller_app/ui/screens/ordenes_activas_screen.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// El tablero del taller: qué motos hay dentro y en qué estado.
///
/// Es la primera pantalla que se abre cada mañana. Si una orden no aparece en
/// su pestaña, para el taller no existe.
void main() {
  late FuenteDeDatosFalsa db;
  late OrdenesProvider ordenesProvider;
  late Cliente cliente;
  late Vehiculo moto;

  setUp(() {
    db = FuenteDeDatosFalsa();
    ordenesProvider = OrdenesProvider(db: db);

    cliente = Cliente(
      nombre: 'Johan',
      apellido: 'Parada',
      tipoDocumento: TipoDocumento.cc,
      numeroDocumento: '1098765432',
      telefono: '3150000000',
    );
    moto = Vehiculo(
      clienteId: cliente.id,
      placaPatente: 'CLA87A',
      marca: 'AKT',
      modelo: 'NKD 125',
      anio: 2020,
    );
    db.clientes.add(cliente);
    db.vehiculos.add(moto);
  });

  OrdenMantenimiento crearOrden({
    required String numero,
    EstadoOrden estado = EstadoOrden.ingresada,
    Vehiculo? vehiculo,
    Cliente? duenio,
    String mecanico = 'Luis',
  }) {
    final v = vehiculo ?? moto;
    final c = duenio ?? cliente;
    final orden = OrdenMantenimiento(
      numeroOrden: numero,
      clienteId: c.id,
      vehiculoId: v.id,
      tipoServicio: TiposServicio.preventivo,
      kilometrajeIngreso: 15000,
      mecanicoAsignado: mecanico,
      estado: estado,
      fechaEntrega: estado == EstadoOrden.entregada ? DateTime.now() : null,
    );
    db.ordenes.add(orden);
    return orden;
  }

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<OrdenesProvider>.value(
        value: ordenesProvider,
        child: const MaterialApp(home: OrdenesActivasScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('cada orden aparece en la pestaña de su estado', (tester) async {
    crearOrden(numero: 'OT-00001', estado: EstadoOrden.ingresada);
    crearOrden(numero: 'OT-00002', estado: EstadoOrden.enReparacion);
    await montar(tester);

    // La pestaña inicial es «Ingresada».
    expect(find.text('OT-00001'), findsOneWidget);
    expect(find.text('OT-00002'), findsNothing);

    await tester.tap(find.text(EstadoOrden.enReparacion.label));
    await tester.pumpAndSettle();

    expect(find.text('OT-00002'), findsOneWidget);
    expect(find.text('OT-00001'), findsNothing);
  });

  testWidgets('las entregadas van al historial, no a las pestañas activas',
      (tester) async {
    crearOrden(numero: 'OT-00001', estado: EstadoOrden.ingresada);
    crearOrden(numero: 'OT-00009', estado: EstadoOrden.entregada);
    await montar(tester);

    expect(find.text('OT-00009'), findsNothing);

    await tester.tap(find.text('Historial'));
    await tester.pumpAndSettle();

    expect(find.text('OT-00009'), findsOneWidget);
    expect(find.text('OT-00001'), findsNothing);
  });

  testWidgets('la tarjeta muestra placa, dueño y mecánico', (tester) async {
    crearOrden(numero: 'OT-00001', mecanico: 'Santiago');
    await montar(tester);

    expect(find.text('AKT NKD 125'), findsOneWidget);
    expect(find.text('CLA87A'), findsOneWidget);
    expect(find.text('Dueño: Johan Parada'), findsOneWidget);
    expect(find.text('Santiago'), findsOneWidget);
  });

  testWidgets('una pestaña sin motos lo dice', (tester) async {
    crearOrden(numero: 'OT-00001', estado: EstadoOrden.ingresada);
    await montar(tester);

    await tester.tap(find.text(EstadoOrden.listaParaEntrega.label));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sin motos en'), findsOneWidget);
  });

  group('buscador', () {
    testWidgets('encuentra por placa', (tester) async {
      final otraMoto = Vehiculo(
        clienteId: cliente.id,
        placaPatente: 'XYZ12B',
        marca: 'Bajaj',
        modelo: 'Boxer',
        anio: 2018,
      );
      db.vehiculos.add(otraMoto);
      crearOrden(numero: 'OT-00001');
      crearOrden(numero: 'OT-00002', vehiculo: otraMoto);
      await montar(tester);

      await tester.enterText(find.byType(TextField), 'xyz12b');
      await tester.pumpAndSettle();

      expect(find.text('OT-00002'), findsOneWidget);
      expect(find.text('OT-00001'), findsNothing);
    });

    testWidgets('encuentra por número de orden', (tester) async {
      crearOrden(numero: 'OT-00001');
      crearOrden(numero: 'OT-00002');
      await montar(tester);

      // En minúsculas a propósito: así se comprueba de paso que la búsqueda
      // no distingue mayúsculas, y el texto del propio campo no se confunde
      // con el de la tarjeta al buscarlo.
      await tester.enterText(find.byType(TextField), 'ot-00002');
      await tester.pumpAndSettle();

      expect(find.text('OT-00002'), findsOneWidget);
      expect(find.text('OT-00001'), findsNothing);
    });

    testWidgets('encuentra por nombre del cliente', (tester) async {
      final otroCliente = Cliente(
        nombre: 'Sebastián',
        apellido: 'Jiménez',
        tipoDocumento: TipoDocumento.cc,
        numeroDocumento: '1000000001',
        telefono: '3001112233',
      );
      final otraMoto = Vehiculo(
        clienteId: otroCliente.id,
        placaPatente: 'XYZ12B',
        marca: 'Bajaj',
        modelo: 'Boxer',
        anio: 2018,
      );
      db.clientes.add(otroCliente);
      db.vehiculos.add(otraMoto);
      crearOrden(numero: 'OT-00001');
      crearOrden(numero: 'OT-00002', vehiculo: otraMoto, duenio: otroCliente);
      await montar(tester);

      await tester.enterText(find.byType(TextField), 'sebast');
      await tester.pumpAndSettle();

      expect(find.text('OT-00002'), findsOneWidget);
      expect(find.text('OT-00001'), findsNothing);
    });

    testWidgets('sin coincidencias lo dice, y no como «pestaña vacía»',
        (tester) async {
      crearOrden(numero: 'OT-00001');
      await montar(tester);

      await tester.enterText(find.byType(TextField), 'kryptonita');
      await tester.pumpAndSettle();

      expect(
          find.text('Ninguna orden coincide con la búsqueda.'), findsOneWidget);
      expect(find.textContaining('Sin motos en'), findsNothing);
    });

    testWidgets('la X limpia la búsqueda', (tester) async {
      crearOrden(numero: 'OT-00001');
      await montar(tester);

      await tester.enterText(find.byType(TextField), 'kryptonita');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Limpiar búsqueda'));
      await tester.pumpAndSettle();

      expect(find.text('OT-00001'), findsOneWidget);
    });
  });

  group('historial paginado', () {
    testWidgets('trae la siguiente página al pedirla', (tester) async {
      // Una página son 50. Con 60 entregadas debe salir el botón y, al
      // tocarlo, aparecer las 10 restantes.
      for (var i = 1; i <= 60; i++) {
        crearOrden(
          numero: 'OT-${i.toString().padLeft(5, '0')}',
          estado: EstadoOrden.entregada,
        );
      }
      await montar(tester);

      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();

      expect(ordenesProvider.historial, hasLength(50));
      expect(find.text('60'), findsNothing,
          reason: 'todavía no se han traído todas');

      await tester.dragUntilVisible(
        find.text('Cargar órdenes anteriores'),
        find.byType(ListView).last,
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cargar órdenes anteriores'));
      await tester.pumpAndSettle();

      expect(ordenesProvider.historial, hasLength(60));
      expect(ordenesProvider.hayMasHistorial, isFalse);
    });

    testWidgets('el historial vacío lo dice', (tester) async {
      crearOrden(numero: 'OT-00001');
      await montar(tester);

      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();

      expect(find.text('Historial vacío'), findsOneWidget);
    });
  });
}
