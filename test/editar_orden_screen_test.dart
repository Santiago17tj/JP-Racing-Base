import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/data/models/cliente.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/data/models/repuesto.dart';
import 'package:moto_taller_app/data/models/vehiculo.dart';
import 'package:moto_taller_app/data/providers/ordenes_provider.dart';
import 'package:moto_taller_app/ui/screens/editar_orden_screen.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// Editar una orden ya abierta: cambiar la moto, el kilometraje o el mecánico
/// de un trabajo que está en curso.
///
/// El tamaño de la ventana está puesto para que quepa la fuente de
/// `flutter_test`; estas pruebas no dicen nada de cómo se ve la pantalla.
void main() {
  late FuenteDeDatosFalsa db;
  late OrdenesProvider ordenesProvider;
  late Cliente cliente;
  late Vehiculo moto;
  late Vehiculo segundaMoto;

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
      kilometrajeActual: 15000,
    );
    segundaMoto = Vehiculo(
      clienteId: cliente.id,
      placaPatente: 'XYZ12B',
      marca: 'Bajaj',
      modelo: 'Boxer',
      anio: 2018,
      kilometrajeActual: 41000,
    );
    db.clientes.add(cliente);
    db.vehiculos.addAll([moto, segundaMoto]);
  });

  OrdenMantenimiento crearOrden({
    String tipoServicio = TiposServicio.preventivo,
    bool esCotizacion = false,
  }) {
    final orden = OrdenMantenimiento(
      numeroOrden: 'OT-00014',
      clienteId: cliente.id,
      vehiculoId: moto.id,
      tipoServicio: tipoServicio,
      kilometrajeIngreso: 15000,
      descripcionProblema: 'Suena la cadena',
      mecanicoAsignado: 'Luis',
      estado: EstadoOrden.enReparacion,
      esCotizacion: esCotizacion,
    );
    db.ordenes.add(orden);
    return orden;
  }

  Future<void> montar(WidgetTester tester, OrdenMantenimiento orden) async {
    tester.view.physicalSize = const Size(1100, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ordenesProvider.cargarDatos();

    await tester.pumpWidget(
      ChangeNotifierProvider<OrdenesProvider>.value(
        value: ordenesProvider,
        child: MaterialApp(
          // Empujada sobre otra ruta: al guardar hace `pop`.
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => EditarOrdenScreen(ordenActual: orden)),
                  ),
                  child: const Text('abrir edición'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir edición'));
    await tester.pumpAndSettle();
  }

  Future<void> guardar(WidgetTester tester) async {
    final boton = find.widgetWithText(ElevatedButton, 'GUARDAR CAMBIOS');
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();
  }

  String textoDe(WidgetTester tester, String etiqueta) =>
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, etiqueta))
          .controller
          ?.text ??
      '';

  testWidgets('abre con los datos de la orden ya escritos', (tester) async {
    final orden = crearOrden();
    await montar(tester, orden);

    expect(textoDe(tester, 'Kilometraje de Ingreso'), '15000');
    expect(textoDe(tester, 'Mecánico Responsable'), 'Luis');
    expect(textoDe(tester, 'Problema que reporta el cliente'), 'Suena la cadena');
    expect(find.text('AKT NKD 125 [CLA87A]'), findsOneWidget);
  });

  testWidgets('guardar cambia kilometraje, mecánico y descripción',
      (tester) async {
    final orden = crearOrden();
    await montar(tester, orden);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Kilometraje de Ingreso'), '16250');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mecánico Responsable'), 'Santiago');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Problema que reporta el cliente'),
        'Cadena y piñones');
    await guardar(tester);

    final guardada = db.ordenPorId(orden.id);
    expect(guardada.kilometrajeIngreso, 16250);
    expect(guardada.mecanicoAsignado, 'Santiago');
    expect(guardada.descripcionProblema, 'Cadena y piñones');
    expect(db.ordenes, hasLength(1), reason: 'edita, no crea otra');
    expect(guardada.numeroOrden, 'OT-00014', reason: 'el folio no se toca');
  });

  testWidgets('cambiar de moto guarda la otra del mismo cliente',
      (tester) async {
    final orden = crearOrden();
    await montar(tester, orden);

    await tester.tap(find.byType(DropdownButtonFormField<Vehiculo>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bajaj Boxer [XYZ12B]').last);
    await tester.pumpAndSettle();

    // Al cambiar de moto se propone su kilometraje.
    expect(textoDe(tester, 'Kilometraje de Ingreso'), '41000');

    await guardar(tester);
    expect(db.ordenPorId(orden.id).vehiculoId, segundaMoto.id);
  });

  testWidgets('un tipo de servicio escrito a mano vuelve a salir en «Otro»',
      (tester) async {
    // La orden se creó con un servicio libre; al reabrirla el desplegable no
    // puede casarlo con la lista, así que debe caer en «Otro» conservando el
    // texto. Si se perdiera, el servicio se cambiaría solo al guardar.
    final orden = crearOrden(tipoServicio: 'Rectificada de cilindro');
    await montar(tester, orden);

    expect(
        textoDe(tester, 'Escribir servicio personalizado'),
        'Rectificada de cilindro');

    await guardar(tester);
    expect(db.ordenPorId(orden.id).tipoServicio, 'Rectificada de cilindro');
  });

  testWidgets('sin mecánico ni descripción no se guarda', (tester) async {
    final orden = crearOrden();
    await montar(tester, orden);

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Mecánico Responsable'), '');
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Problema que reporta el cliente'),
        '');
    await guardar(tester);

    expect(find.text('Requerido'), findsWidgets);
    expect(db.ordenPorId(orden.id).mecanicoAsignado, 'Luis',
        reason: 'la orden no debe quedar a medias');
    expect(find.byType(EditarOrdenScreen), findsOneWidget);
  });

  group('convertir entre orden y cotización', () {
    // Hasta el 15/08/2026 este interruptor no guardaba nada: la pantalla lo
    // dejaba mover, decía «Orden actualizada con éxito» y la orden quedaba
    // igual. Importa porque una cotización no descuenta stock y una orden sí.

    Future<void> moverInterruptor(WidgetTester tester) async {
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
    }

    /// Acepta el aviso de cambio de tipo, que sale al pulsar «guardar».
    Future<void> aceptarAviso(WidgetTester tester) async {
      await tester
          .tap(find.widgetWithText(ElevatedButton, 'Entendido, cambiar'));
      await tester.pumpAndSettle();
    }

    testWidgets('convertir una orden en cotización se guarda de verdad',
        (tester) async {
      final orden = crearOrden(esCotizacion: false);
      await montar(tester, orden);
      await moverInterruptor(tester);
      await guardar(tester);

      // Avisa antes de hacerlo: el cambio no reajusta el stock ya movido.
      expect(find.text('Convertir en cotización'), findsOneWidget);
      await aceptarAviso(tester);

      expect(db.ordenPorId(orden.id).esCotizacion, isTrue);
      expect(find.text('Orden actualizada con éxito'), findsOneWidget);
    });

    testWidgets('convertir una cotización en orden también', (tester) async {
      final orden = crearOrden(esCotizacion: true);
      await montar(tester, orden);
      await moverInterruptor(tester);
      await guardar(tester);

      expect(find.text('Convertir en orden'), findsOneWidget);
      await aceptarAviso(tester);

      expect(db.ordenPorId(orden.id).esCotizacion, isFalse);
    });

    testWidgets('cancelar el aviso no cambia el tipo ni guarda lo demás',
        (tester) async {
      final orden = crearOrden(esCotizacion: false);
      await montar(tester, orden);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Mecánico Responsable'), 'Santiago');
      await moverInterruptor(tester);
      await guardar(tester);

      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(db.ordenPorId(orden.id).esCotizacion, isFalse);
      expect(db.ordenPorId(orden.id).mecanicoAsignado, 'Luis',
          reason: 'cancelar cancela la edición entera, no solo el tipo');
      expect(find.byType(EditarOrdenScreen), findsOneWidget);
    });

    testWidgets('sin tocar el interruptor no se pregunta nada', (tester) async {
      final orden = crearOrden(esCotizacion: false);
      await montar(tester, orden);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Mecánico Responsable'), 'Santiago');
      await guardar(tester);

      expect(find.textContaining('Convertir en'), findsNothing);
      expect(db.ordenPorId(orden.id).mecanicoAsignado, 'Santiago');
      expect(db.ordenPorId(orden.id).esCotizacion, isFalse);
    });

    testWidgets('el cambio no devuelve al inventario el stock ya descontado',
        (tester) async {
      // Es la decisión de fondo, y por eso el aviso: esas piezas ya están
      // montadas en la moto. Devolverlas al stock sería inventar existencias.
      final orden = crearOrden(esCotizacion: false);
      final rep = Repuesto(
        codigoInterno: 'BOM-001',
        nombre: 'Bomba de aceite nkd',
        categoria: CategoriaRepuesto.motor,
        stockActual: 10,
        stockMinimo: 2,
        precioCosto: 60000,
        precioVenta: 120000,
      );
      db.repuestos.add(rep);
      await db.agregarItemAOrden(
        ordenId: orden.id,
        repuestoId: rep.id,
        cantidad: 3,
        precioUnitario: rep.precioVenta,
        descripcion: rep.nombre,
      );
      expect(db.repuestoPorId(rep.id).stockActual, 7);

      await montar(tester, db.ordenPorId(orden.id));
      await moverInterruptor(tester);
      await guardar(tester);
      await aceptarAviso(tester);

      expect(db.ordenPorId(orden.id).esCotizacion, isTrue);
      expect(db.repuestoPorId(rep.id).stockActual, 7,
          reason: 'el stock ya movido se queda como está');
    });
  });
}
