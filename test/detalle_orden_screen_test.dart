import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/core/dominio/reglas_orden.dart';
import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'package:moto_taller_app/data/models/cliente.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/data/models/perfil_taller.dart';
import 'package:moto_taller_app/data/models/repuesto.dart';
import 'package:moto_taller_app/data/models/vehiculo.dart';
import 'package:moto_taller_app/data/providers/inventario_provider.dart';
import 'package:moto_taller_app/data/providers/ordenes_provider.dart';
import 'package:moto_taller_app/data/providers/taller_provider.dart';
import 'package:moto_taller_app/ui/screens/detalle_orden_screen.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// Pruebas de la pantalla donde se añaden repuestos, se registra mano de obra y
/// se cobra. Es la que más dinero mueve de las 22.
///
/// Todas las cifras esperadas se escriben a mano, tomadas de una factura real
/// del taller (OT-00014) o calculadas aparte. Si una prueba comparara contra
/// `ReglasOrden` pasaría igual con las cuentas mal.
void main() {
  const double iva = 19.0;

  late FuenteDeDatosFalsa db;
  late OrdenesProvider ordenesProvider;
  late InventarioProvider inventarioProvider;
  late TallerProvider tallerProvider;

  late Cliente cliente;
  late Vehiculo vehiculo;

  setUp(() {
    db = FuenteDeDatosFalsa();

    cliente = Cliente(
      nombre: 'Johan',
      apellido: 'Parada',
      tipoDocumento: TipoDocumento.cc,
      numeroDocumento: '1098765432',
      telefono: '3150000000',
    );
    vehiculo = Vehiculo(
      clienteId: cliente.id,
      placaPatente: 'CLA87A',
      marca: 'AKT',
      modelo: 'NKD 125',
      anio: 2020,
    );
    db.clientes.add(cliente);
    db.vehiculos.add(vehiculo);

    ordenesProvider = OrdenesProvider(db: db);
    inventarioProvider = InventarioProvider(db: db);
    tallerProvider = TallerProvider(db: db);
    tallerProvider.setTaller(PerfilTaller(
      usuarioAdministradorId: 'admin',
      nombreTaller: 'JP.RACING.315',
      porcentajeImpuestoDefecto: iva,
    ));
  });

  /// Orden de trabajo lista para el fixture. Los valores por defecto son los de
  /// una orden recién abierta.
  OrdenMantenimiento crearOrden({
    double costoManoObra = 0,
    double subtotalRepuestos = 0,
    double montoPagado = 0,
    String? estadoPago,
    EstadoOrden estado = EstadoOrden.enReparacion,
    String numeroOrden = 'OT-00014',
  }) {
    final orden = OrdenMantenimiento(
      numeroOrden: numeroOrden,
      clienteId: cliente.id,
      vehiculoId: vehiculo.id,
      tipoServicio: 'Mantenimiento',
      kilometrajeIngreso: 15000,
      descripcionProblema: 'Suena la cadena',
      mecanicoAsignado: 'Luis',
      estado: estado,
      costoManoObra: costoManoObra,
      subtotalRepuestos: subtotalRepuestos,
      montoPagado: montoPagado,
      estadoPago: estadoPago,
    );
    db.ordenes.add(orden);
    return orden;
  }

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

  Future<void> montar(WidgetTester tester, OrdenMantenimiento orden) async {
    // La pantalla es una lista larga: con los 800x600 por defecto los totales
    // quedan fuera del árbol y las pruebas mirarían a un sitio vacío.
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await ordenesProvider.cargarDatos();
    await inventarioProvider.cargarRepuestos();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<OrdenesProvider>.value(value: ordenesProvider),
          ChangeNotifierProvider<InventarioProvider>.value(
              value: inventarioProvider),
          ChangeNotifierProvider<TallerProvider>.value(value: tallerProvider),
        ],
        child: MaterialApp(
          home: DetalleOrdenScreen(
            orden: orden,
            cliente: cliente,
            vehiculo: vehiculo,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String pesos(double valor) => CurrencyFormatter.format(valor);

  group('cifras en pantalla', () {
    testWidgets('el saldo pendiente incluye el IVA (OT-00014)',
        (tester) async {
      // La factura real decía saldo $1.085.000 cuando el cliente debía
      // $1.132.500: se calculaba sobre el total SIN IVA. La orden se guarda
      // aquí con ese saldo equivocado a propósito; la pantalla tiene que
      // ignorarlo y calcularlo con impuesto.
      final orden = crearOrden(
        subtotalRepuestos: 850000,
        costoManoObra: 250000,
        montoPagado: 15000,
      );
      expect(orden.saldoPendiente, 1085000,
          reason: 'el modelo sigue guardando el saldo sin IVA, por diseño');

      await montar(tester, orden);

      expect(find.text(pesos(1147500)), findsWidgets); // total con IVA
      expect(find.text(pesos(47500)), findsOneWidget); // IVA de la mano de obra
      expect(find.text(pesos(1132500)), findsOneWidget); // saldo real
      expect(find.text(pesos(1085000)), findsNothing);
      expect(find.text('PAGO PARCIAL'), findsOneWidget);
    });

    testWidgets('el IVA no toca los repuestos', (tester) async {
      // Los repuestos se compran con el impuesto incluido: cobrárselo otra vez
      // sería cobrarlo dos veces.
      final orden = crearOrden(subtotalRepuestos: 500000, costoManoObra: 0);
      await montar(tester, orden);

      expect(find.text('Subtotal Repuestos (IVA incl.)'), findsOneWidget);
      expect(find.text(pesos(500000)), findsWidgets);
      // Total = repuestos, sin un peso de impuesto encima.
      expect(find.textContaining('IVA 19.0%'), findsNothing);
    });

    testWidgets('una orden marcada como pagada pero con saldo por el IVA no '
        'se muestra como PAGADO', (tester) async {
      // El estado guardado se calculó sin impuesto. Si aún queda por cobrar,
      // decir PAGADO haría que el taller cerrara la orden sin ese dinero.
      final orden = crearOrden(
        costoManoObra: 250000,
        montoPagado: 250000,
        estadoPago: 'pagado',
      );
      await montar(tester, orden);

      expect(find.text('PAGADO'), findsNothing);
      expect(find.text('PAGO PARCIAL'), findsOneWidget);
      // Dos veces: la línea del IVA y el recuadro «Pendiente». Lo que falta
      // por cobrar es exactamente el impuesto que el estado guardado ignoró.
      expect(find.text(pesos(47500)), findsNWidgets(2));
    });
  });

  group('mano de obra', () {
    testWidgets('se acumula en costoManoObra y no en el subtotal de repuestos',
        (tester) async {
      final orden = crearOrden();
      await montar(tester, orden);

      await tester.tap(find.byTooltip('Mano de Obra'));
      await tester.pumpAndSettle();

      final campos = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(campos.at(0), 'Cambio de guaya');
      await tester.enterText(campos.at(1), '250000');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Agregar'));
      await tester.pumpAndSettle();

      final guardada = db.ordenPorId(orden.id);
      expect(guardada.costoManoObra, 250000);
      expect(guardada.subtotalRepuestos, 0,
          reason: 'sumarla aquí también la cobraría dos veces');

      // El ítem existe solo para que salga detallado en la factura.
      final items = db.itemsDe(orden.id);
      expect(items, hasLength(1));
      expect(ReglasOrden.esManoObra(items.single), isTrue);

      expect(find.text('- Cambio de guaya'), findsOneWidget);
      expect(find.text(pesos(297500)), findsWidgets); // 250.000 + IVA
    });

    testWidgets('eliminar un concepto descuenta su valor de la mano de obra',
        (tester) async {
      final orden = crearOrden();
      await db.agregarManoObraAOrden(
          orden.id, 250000, 'Mano de obra: Cambio de guaya');
      await db.agregarManoObraAOrden(
          orden.id, 80000, 'Mano de obra: Sincronización');
      await montar(tester, db.ordenPorId(orden.id));

      expect(db.ordenPorId(orden.id).costoManoObra, 330000);

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(db.ordenPorId(orden.id).costoManoObra, 80000);
      expect(db.itemsDe(orden.id), hasLength(1));
      expect(find.text('- Cambio de guaya'), findsNothing);
      expect(find.text('- Sincronización'), findsOneWidget);
    });
  });

  group('repuestos', () {
    testWidgets('añadir uno del inventario descuenta stock y sube el subtotal',
        (tester) async {
      final orden = crearOrden();
      final rep = crearRepuesto(stock: 10, precioVenta: 120000);
      await montar(tester, orden);

      await tester.tap(find.byTooltip('Agregar Repuesto'));
      await tester.pumpAndSettle();

      expect(find.text('Bomba de aceite nkd'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add)); // cantidad 1 → 2
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pumpAndSettle();

      expect(db.repuestoPorId(rep.id).stockActual, 8);
      expect(db.ordenPorId(orden.id).subtotalRepuestos, 240000);
      expect(find.text('Cantidad: 2 x ${pesos(120000)}'), findsOneWidget);
      expect(find.text(pesos(240000)), findsWidgets);
    });

    testWidgets('eliminarlo devuelve el stock al inventario', (tester) async {
      final orden = crearOrden();
      final rep = crearRepuesto(stock: 10, precioVenta: 120000);
      await db.agregarItemAOrden(
        ordenId: orden.id,
        repuestoId: rep.id,
        cantidad: 3,
        precioUnitario: rep.precioVenta,
        descripcion: rep.nombre,
      );
      expect(db.repuestoPorId(rep.id).stockActual, 7);

      await montar(tester, db.ordenPorId(orden.id));

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
      expect(find.textContaining('El stock del repuesto será restaurado'),
          findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Eliminar'));
      await tester.pumpAndSettle();

      expect(db.repuestoPorId(rep.id).stockActual, 10);
      expect(db.ordenPorId(orden.id).subtotalRepuestos, 0);
      expect(db.itemsDe(orden.id), isEmpty);
    });

    testWidgets('cancelar la confirmación no borra nada', (tester) async {
      final orden = crearOrden();
      final rep = crearRepuesto();
      await db.agregarItemAOrden(
        ordenId: orden.id,
        repuestoId: rep.id,
        cantidad: 1,
        precioUnitario: rep.precioVenta,
        descripcion: rep.nombre,
      );
      await montar(tester, db.ordenPorId(orden.id));

      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
      await tester.pumpAndSettle();

      expect(db.itemsDe(orden.id), hasLength(1));
      expect(db.repuestoPorId(rep.id).stockActual, 9);
    });

    testWidgets('el repuesto externo no toca el inventario', (tester) async {
      final orden = crearOrden();
      final rep = crearRepuesto(stock: 10);
      await montar(tester, orden);

      await tester.tap(find.byTooltip('Repuesto Externo'));
      await tester.pumpAndSettle();

      final campos = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(campos.at(0), 'Cadena 520 RK Racing');
      await tester.enterText(campos.at(1), '95000');
      await tester.enterText(campos.at(2), '2');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Agregar'));
      await tester.pumpAndSettle();

      expect(db.repuestoPorId(rep.id).stockActual, 10);
      expect(db.ordenPorId(orden.id).subtotalRepuestos, 190000);
      expect(db.itemsDe(orden.id).single.repuestoId,
          ReglasOrden.idRepuestoExterno);
      expect(find.text('Cadena 520 RK Racing'), findsOneWidget);
    });
  });

  group('cobro', () {
    testWidgets('un abono baja el saldo con IVA y entra en caja',
        (tester) async {
      final orden = crearOrden(
        subtotalRepuestos: 850000,
        costoManoObra: 250000,
        montoPagado: 15000,
      );
      await montar(tester, orden);

      await tester.tap(find.text('💵 Registrar Abono / Anticipo'));
      await tester.pumpAndSettle();

      // El diálogo debe partir del saldo con impuesto, no del guardado.
      expect(find.text('Saldo pendiente: ${pesos(1132500)}'), findsOneWidget);

      await tester.enterText(
        find
            .descendant(
                of: find.byType(AlertDialog), matching: find.byType(TextField))
            .first,
        '100000',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar Abono'));
      await tester.pumpAndSettle();

      final guardada = db.ordenPorId(orden.id);
      expect(guardada.montoPagado, 115000);
      expect(guardada.saldoPendiente, 1032500);
      expect(guardada.estadoPago, 'parcial');

      expect(db.abonos.single.monto, 100000);
      expect(db.caja.single.tipo, 'ingreso');
      expect(db.caja.single.monto, 100000);
      expect(db.caja.single.concepto, contains('OT-00014'));

      expect(find.text(pesos(1032500)), findsWidgets);
    });

    testWidgets('un abono de cero no se registra', (tester) async {
      final orden = crearOrden(costoManoObra: 100000);
      await montar(tester, orden);

      await tester.tap(find.text('💵 Registrar Abono / Anticipo'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find
            .descendant(
                of: find.byType(AlertDialog), matching: find.byType(TextField))
            .first,
        '0',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Guardar Abono'));
      await tester.pumpAndSettle();

      expect(db.abonos, isEmpty);
      expect(db.caja, isEmpty);
      expect(find.text('Ingrese un monto válido mayor a 0'), findsOneWidget);
    });
  });

  group('facturación', () {
    testWidgets('el botón está apagado mientras la moto no está lista',
        (tester) async {
      final orden = crearOrden(estado: EstadoOrden.enReparacion);
      await montar(tester, orden);

      final boton = tester.widget<ElevatedButton>(find.widgetWithText(
          ElevatedButton, 'GENERAR FACTURA INVOICE FLY'));
      expect(boton.onPressed, isNull);
      expect(find.textContaining('Lista para Entrega'), findsWidgets);
    });

    testWidgets('se enciende cuando la orden está lista para entrega',
        (tester) async {
      final orden = crearOrden(estado: EstadoOrden.listaParaEntrega);
      await montar(tester, orden);

      final boton = tester.widget<ElevatedButton>(find.widgetWithText(
          ElevatedButton, 'GENERAR FACTURA INVOICE FLY'));
      expect(boton.onPressed, isNotNull);
    });
  });
}
