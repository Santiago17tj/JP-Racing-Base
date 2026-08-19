import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/data/models/cliente.dart';
import 'package:moto_taller_app/data/models/orden_item.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/data/models/perfil_taller.dart';
import 'package:moto_taller_app/data/models/registro_caja.dart';
import 'package:moto_taller_app/data/models/repuesto.dart';
import 'package:moto_taller_app/data/models/vehiculo.dart';
import 'package:moto_taller_app/data/providers/inventario_provider.dart';
import 'package:moto_taller_app/data/providers/ordenes_provider.dart';
import 'package:moto_taller_app/data/providers/sesion_local_provider.dart';
import 'package:moto_taller_app/data/providers/taller_provider.dart';
import 'package:moto_taller_app/ui/screens/contabilidad_screen.dart';
import 'package:moto_taller_app/ui/screens/crear_orden_screen.dart';
import 'package:moto_taller_app/ui/screens/detalle_orden_screen.dart';
import 'package:moto_taller_app/ui/screens/inventario_screen.dart';
import 'package:moto_taller_app/ui/screens/ordenes_activas_screen.dart';
import 'package:moto_taller_app/ui/screens/venta_rapida_screen.dart';
import 'package:moto_taller_app/ui/widgets/factura_preview_sheet.dart';

import 'ayudas/fuente_de_datos_falsa.dart';
import 'ayudas/fuente_real.dart';

/// **Las únicas pruebas del proyecto que miran cómo se ve la app.**
///
/// Las otras 173 de interfaz comprueban contenido y comportamiento con la
/// fuente por defecto de `flutter_test`, que dibuja cada carácter como un
/// cuadrado del alto de la letra: con ella no se puede medir nada. Aquí se
/// carga **Roboto de verdad** (viene con el SDK) y se montan las pantallas a
/// **tamaños de teléfono reales**.
///
/// Cómo funcionan: un desbordamiento de `Row`/`Column` hace fallar la prueba
/// por sí solo, sin necesidad de aserción. Montar la pantalla **es** la
/// comprobación. Los `expect` de abajo están para que quede claro qué se
/// esperaba ver y para que la prueba no pase vacía si algo dejara de montarse.
///
/// **Lo que estas pruebas siguen sin garantizar**: la app no usa Roboto, usa
/// Inter (`GoogleFonts.interTextTheme()`), que se descarga en tiempo de
/// ejecución y en pruebas no está disponible. Roboto es una aproximación
/// buena —las dos son tipografías de interfaz de anchos parecidos— pero no
/// exacta. Un margen de dos o tres píxeles puede comportarse distinto en el
/// teléfono.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(cargarRoboto);

  /// Teléfonos con los que se mide, en píxeles lógicos.
  ///
  /// El estrecho es un móvil pequeño y es el caso peor; 360×800 es de lejos el
  /// tamaño más común en Android. La tablet entra porque `venta_rapida` cambia
  /// de disposición a partir de 700 y ahí el resumen se queda en 320 px.
  const telefonoPequeno = Size(320, 640);
  const telefonoComun = Size(360, 800);
  const tablet = Size(1024, 768);

  late FuenteDeDatosFalsa db;
  late OrdenesProvider ordenesProvider;
  late InventarioProvider inventarioProvider;
  late TallerProvider tallerProvider;
  late SesionLocalProvider sesionProvider;
  late Cliente cliente;
  late Vehiculo moto;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FuenteDeDatosFalsa();
    ordenesProvider = OrdenesProvider(db: db);
    inventarioProvider = InventarioProvider(db: db);
    tallerProvider = TallerProvider(db: db);
    sesionProvider = SesionLocalProvider();
    tallerProvider.setTaller(PerfilTaller(
      usuarioAdministradorId: 'admin',
      nombreTaller: 'JP.RACING.315',
      porcentajeImpuestoDefecto: 19,
    ));

    cliente = Cliente(
      nombre: 'Johan Sebastián',
      apellido: 'Parada Aragón',
      tipoDocumento: TipoDocumento.cc,
      numeroDocumento: '1098765432',
      telefono: '3150000000',
    );
    moto = Vehiculo(
      clienteId: cliente.id,
      placaPatente: 'CLA87A',
      marca: 'AKT',
      modelo: 'NKD 125 Sport',
      anio: 2020,
    );
    db.clientes.add(cliente);
    db.vehiculos.add(moto);
  });

  /// Monta [pantalla] a [tamano] con Roboto cargado.
  Future<void> montar(
    WidgetTester tester,
    Size tamano,
    Widget pantalla,
  ) async {
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
          ChangeNotifierProvider<TallerProvider>.value(value: tallerProvider),
          ChangeNotifierProvider<SesionLocalProvider>.value(
              value: sesionProvider),
        ],
        child: MaterialApp(
          // Se fuerza la familia porque `AppTheme` usa `GoogleFonts`, que
          // descarga la fuente y en pruebas no tiene red: sin esto volveríamos
          // a medir con la fuente de mentira.
          theme: ThemeData(fontFamily: 'Roboto'),
          home: pantalla,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Repuesto crearRepuesto({
    String nombre = 'Bomba de aceite nkd original AKT',
    String codigo = 'BOM-0012345',
    int stock = 128,
    double precioVenta = 1250000,
  }) {
    final rep = Repuesto(
      codigoInterno: codigo,
      nombre: nombre,
      categoria: CategoriaRepuesto.motor,
      marcaRepuesto: 'AKT Original',
      stockActual: stock,
      stockMinimo: 2,
      precioCosto: precioVenta / 2,
      precioVenta: precioVenta,
    );
    db.repuestos.add(rep);
    return rep;
  }

  OrdenMantenimiento crearOrden({double manoObra = 250000}) {
    final orden = OrdenMantenimiento(
      numeroOrden: 'OT-00014',
      clienteId: cliente.id,
      vehiculoId: moto.id,
      tipoServicio: TiposServicio.reparacionMayor,
      kilometrajeIngreso: 158000,
      descripcionProblema: 'Suena la cadena y pierde fuerza en subida',
      mecanicoAsignado: 'Luis Santiago',
      estado: EstadoOrden.enReparacion,
      costoManoObra: manoObra,
      subtotalRepuestos: 1850000,
      montoPagado: 150000,
    );
    db.ordenes.add(orden);
    return orden;
  }

  // Las cifras y los textos de los fixtures son deliberadamente largos —
  // millones de pesos, nombres completos, referencias de repuesto de once
  // caracteres— porque un desbordamiento aparece con el caso peor, no con
  // «Ana» y «$100».

  group('teléfono pequeño (320×640)', () {
    testWidgets('venta rápida con el carrito lleno', (tester) async {
      crearRepuesto();
      await inventarioProvider.cargarRepuestos();
      await montar(tester, telefonoPequeno, const VentaRapidaScreen());

      await tester.enterText(find.byType(TextField).first, 'bomba');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(find.text('TOTAL COBRAR'), findsOneWidget);
    }, skip: sinFuenteReal());

    testWidgets('inventario con un repuesto de nombre y precio largos',
        (tester) async {
      crearRepuesto();
      await montar(tester, telefonoPequeno, const InventarioScreen());

      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    }, skip: sinFuenteReal());

    testWidgets('contabilidad con las tres tarjetas de métricas',
        (tester) async {
      db.caja.add(RegistroCaja(
        tipo: 'ingreso',
        monto: 12500000,
        concepto: 'Pago de Orden #OT-00012 (Frenos, motor y transmisión)',
        fecha: DateTime(2026, 8, 14, 10),
      ));
      await montar(tester, telefonoPequeno, const ContabilidadScreen());

      expect(find.text('Ganancia Neta'), findsOneWidget);
    }, skip: sinFuenteReal());

    testWidgets('detalle de orden con repuestos y mano de obra',
        (tester) async {
      final orden = crearOrden();
      await db.agregarManoObraAOrden(
          orden.id, 250000, 'Mano de obra: sincronización de válvulas');
      final rep = crearRepuesto();
      await db.agregarItemAOrden(
        ordenId: orden.id,
        repuestoId: rep.id,
        cantidad: 12,
        precioUnitario: rep.precioVenta,
        descripcion: rep.nombre,
      );
      await ordenesProvider.cargarDatos();

      await montar(
        tester,
        telefonoPequeno,
        DetalleOrdenScreen(
            orden: db.ordenPorId(orden.id), cliente: cliente, vehiculo: moto),
      );

      // En una pantalla de 640 px de alto los totales quedan bajo el pliegue,
      // y una lista no construye lo que no se ve: hay que bajar hasta ellos
      // para que lleguen a medirse.
      await tester.scrollUntilVisible(
        find.text('TOTAL ESTIMADO'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(find.text('TOTAL ESTIMADO'), findsOneWidget);
    }, skip: sinFuenteReal());

    testWidgets('la cabecera de la orden separa kilometraje, servicio y mecánico',
        (tester) async {
      // En el teléfono del taller salía «Mantenimiento PreventivoJuan David
      // parada», todo pegado: las tres celdas se repartían el ancho con
      // `spaceBetween`, que no deja hueco cuando ya lo ocupan entero. No
      // llegaba a desbordar, así que solo se ve mirando.
      // Los datos exactos que se vieron pegados en el telefono del taller.
      final orden = OrdenMantenimiento(
        numeroOrden: 'OT-00017',
        clienteId: cliente.id,
        vehiculoId: moto.id,
        tipoServicio: TiposServicio.preventivo,
        kilometrajeIngreso: 4684,
        mecanicoAsignado: 'Juan David parada',
        estado: EstadoOrden.listaParaEntrega,
      );
      db.ordenes.add(orden);
      await ordenesProvider.cargarDatos();
      await montar(
        tester,
        telefonoComun,
        DetalleOrdenScreen(orden: orden, cliente: cliente, vehiculo: moto),
      );

      final servicio = tester.getRect(find.text(TiposServicio.preventivo));
      final mecanico = tester.getRect(find.text('Juan David parada'));

      expect(servicio.right, lessThan(mecanico.left),
          reason: 'el tipo de servicio y el mecánico no pueden tocarse');
    }, skip: sinFuenteReal());

    testWidgets('órdenes activas con una tarjeta completa', (tester) async {
      crearOrden(); // nace en «En Reparación», que no es la pestaña inicial
      await montar(tester, telefonoPequeno, const OrdenesActivasScreen());

      await tester.tap(find.text(EstadoOrden.enReparacion.label));
      await tester.pumpAndSettle();

      expect(find.text('OT-00014'), findsOneWidget);
    }, skip: sinFuenteReal());

    testWidgets('check-in de moto', (tester) async {
      await montar(tester, telefonoPequeno, const CrearOrdenScreen());

      expect(find.text('Nuevo Cliente'), findsOneWidget);
    }, skip: sinFuenteReal());

    testWidgets('vista previa de la factura', (tester) async {
      final orden = crearOrden();
      await montar(
        tester,
        telefonoPequeno,
        Scaffold(
          body: FacturaPreviewSheet(
            orden: orden,
            cliente: cliente,
            vehiculo: moto,
            items: [
              OrdenItem(
                ordenId: orden.id,
                repuestoId: 'r1',
                descripcion: 'Bomba de aceite nkd original AKT',
                cantidad: 12,
                precioUnitario: 1250000,
              ),
            ],
          ),
        ),
      );

      expect(find.text('TOTAL'), findsOneWidget);
    }, skip: sinFuenteReal());
  });

  group('teléfono común (360×800)', () {
    testWidgets('venta rápida con el carrito lleno', (tester) async {
      crearRepuesto();
      await inventarioProvider.cargarRepuestos();
      await montar(tester, telefonoComun, const VentaRapidaScreen());

      await tester.enterText(find.byType(TextField).first, 'bomba');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(find.text('TOTAL COBRAR'), findsOneWidget);
    }, skip: sinFuenteReal());

    testWidgets('inventario', (tester) async {
      crearRepuesto();
      await montar(tester, telefonoComun, const InventarioScreen());

      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    }, skip: sinFuenteReal());

    testWidgets('detalle de orden', (tester) async {
      final orden = crearOrden();
      await ordenesProvider.cargarDatos();
      await montar(
        tester,
        telefonoComun,
        DetalleOrdenScreen(orden: orden, cliente: cliente, vehiculo: moto),
      );

      expect(find.text('TOTAL ESTIMADO'), findsOneWidget);
    }, skip: sinFuenteReal());
  });

  group('tablet (1024×768)', () {
    testWidgets('venta rápida usa el panel lateral de 320 px', (tester) async {
      // Es la caja más apretada de la app: el botón «REGISTRAR VENTA (PAGADA)»
      // mide unos 199 px con Roboto y el panel le deja unos 197 descontando el
      // icono y el margen. Va tan justo que merece su propia prueba.
      crearRepuesto();
      await inventarioProvider.cargarRepuestos();
      await montar(tester, tablet, const VentaRapidaScreen());

      await tester.enterText(find.byType(TextField).first, 'bomba');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(find.text('REGISTRAR VENTA (PAGADA)'), findsOneWidget);
    }, skip: sinFuenteReal());
  });
}
