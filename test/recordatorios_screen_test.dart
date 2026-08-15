import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/data/models/cliente.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/data/models/perfil_taller.dart';
import 'package:moto_taller_app/data/models/vehiculo.dart';
import 'package:moto_taller_app/data/providers/ordenes_provider.dart';
import 'package:moto_taller_app/data/providers/taller_provider.dart';
import 'package:moto_taller_app/ui/screens/recordatorios_screen.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// A qué clientes toca llamar para el próximo mantenimiento.
///
/// Es la pantalla que hace volver la moto al taller: si una moto que lleva
/// medio año sin venir no aparece aquí, ese trabajo se pierde.
void main() {
  late FuenteDeDatosFalsa db;
  late OrdenesProvider ordenesProvider;
  late TallerProvider tallerProvider;
  late Cliente cliente;
  late Vehiculo moto;

  setUp(() {
    db = FuenteDeDatosFalsa();
    ordenesProvider = OrdenesProvider(db: db);
    tallerProvider = TallerProvider(db: db);
    tallerProvider.setTaller(PerfilTaller(
      usuarioAdministradorId: 'admin',
      nombreTaller: 'JP.RACING.315',
    ));

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

  /// Orden entregada hace [diasAtras] días.
  OrdenMantenimiento entregadaHace(int diasAtras,
      {String numero = 'OT-00001', Vehiculo? vehiculo, int kilometraje = 15000}) {
    final fecha = DateTime.now().subtract(Duration(days: diasAtras));
    final orden = OrdenMantenimiento(
      numeroOrden: numero,
      clienteId: cliente.id,
      vehiculoId: (vehiculo ?? moto).id,
      tipoServicio: TiposServicio.preventivo,
      kilometrajeIngreso: kilometraje,
      estado: EstadoOrden.entregada,
      fechaIngreso: fecha,
      fechaEntrega: fecha,
    );
    db.ordenes.add(orden);
    return orden;
  }

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ordenesProvider.cargarDatos();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<OrdenesProvider>.value(value: ordenesProvider),
          ChangeNotifierProvider<TallerProvider>.value(value: tallerProvider),
        ],
        child: const MaterialApp(home: RecordatoriosScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('una moto que ya cumplió el intervalo aparece con «YA TOCA»',
      (tester) async {
    entregadaHace(100); // el intervalo por defecto son 90 días
    await montar(tester);

    expect(find.text('AKT NKD 125'), findsOneWidget);
    expect(find.text('YA TOCA'), findsOneWidget);
    expect(find.textContaining('Último servicio hace 100 días'), findsOneWidget);
    expect(find.textContaining('OT-00001'), findsOneWidget);
  });

  testWidgets('una que se pasó del doble sale como «HACE MUCHO»',
      (tester) async {
    entregadaHace(200);
    await montar(tester);

    expect(find.text('HACE MUCHO'), findsOneWidget);
  });

  testWidgets('una recién atendida no aparece', (tester) async {
    entregadaHace(5);
    await montar(tester);

    expect(find.text('Ninguna moto está pendiente'), findsOneWidget);
    expect(find.text('AKT NKD 125'), findsNothing);
  });

  testWidgets('sin órdenes no hay a quién llamar', (tester) async {
    await montar(tester);

    expect(find.text('Ninguna moto está pendiente'), findsOneWidget);
  });

  testWidgets('cambiar el intervalo cambia a quién hay que llamar',
      (tester) async {
    // A 90 días una moto de hace 100 ya toca; subiendo el intervalo a 180
    // todavía no.
    entregadaHace(100);
    await montar(tester);
    expect(find.text('YA TOCA'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 meses').last);
    await tester.pumpAndSettle();

    expect(find.text('YA TOCA'), findsNothing);
    expect(find.text('Ninguna moto está pendiente'), findsOneWidget);
  });

  testWidgets('de una moto con varias órdenes cuenta solo la última',
      (tester) async {
    entregadaHace(300, numero: 'OT-00001', kilometraje: 10000);
    entregadaHace(100, numero: 'OT-00002', kilometraje: 15000);
    await montar(tester);

    // Una sola tarjeta, y la de la orden más reciente.
    expect(find.text('AKT NKD 125'), findsOneWidget);
    expect(find.textContaining('OT-00002'), findsOneWidget);
    expect(find.textContaining('OT-00001'), findsNothing);
    expect(find.textContaining('15000 km'), findsOneWidget);
  });

  testWidgets('cada moto del mismo cliente cuenta por separado',
      (tester) async {
    final otraMoto = Vehiculo(
      clienteId: cliente.id,
      placaPatente: 'XYZ12B',
      marca: 'Bajaj',
      modelo: 'Boxer',
      anio: 2018,
    );
    db.vehiculos.add(otraMoto);
    entregadaHace(100, numero: 'OT-00001');
    entregadaHace(150, numero: 'OT-00002', vehiculo: otraMoto);
    await montar(tester);

    expect(find.text('AKT NKD 125'), findsOneWidget);
    expect(find.text('Bajaj Boxer'), findsOneWidget);
  });

  testWidgets('cada tarjeta ofrece escribirle al dueño', (tester) async {
    entregadaHace(100);
    await montar(tester);

    expect(find.text('Escribirle por WhatsApp'), findsOneWidget);
    expect(find.textContaining('CLA87A'), findsOneWidget);
    expect(find.textContaining('Johan Parada'), findsOneWidget);
  });
}
