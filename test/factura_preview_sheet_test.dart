import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moto_taller_app/core/constants/enums.dart';
import 'package:moto_taller_app/core/dominio/reglas_orden.dart';
import 'package:moto_taller_app/core/utils/currency_formatter.dart';
import 'package:moto_taller_app/data/models/cliente.dart';
import 'package:moto_taller_app/data/models/orden_item.dart';
import 'package:moto_taller_app/data/models/orden_mantenimiento.dart';
import 'package:moto_taller_app/data/models/perfil_taller.dart';
import 'package:moto_taller_app/data/models/vehiculo.dart';
import 'package:moto_taller_app/data/providers/taller_provider.dart';
import 'package:moto_taller_app/ui/widgets/factura_preview_sheet.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// La hoja que el taller le enseña al cliente antes de mandarle la factura.
///
/// Es la última pantalla donde una cifra equivocada todavía se puede corregir:
/// después ya salió en un PDF por WhatsApp.
void main() {
  late FuenteDeDatosFalsa db;
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
    tallerProvider = TallerProvider(db: db);
  });

  void configurarTaller(double iva) {
    tallerProvider.setTaller(PerfilTaller(
      usuarioAdministradorId: 'admin',
      nombreTaller: 'JP.RACING.315',
      porcentajeImpuestoDefecto: iva,
    ));
  }

  OrdenMantenimiento orden({
    double costoManoObra = 0,
    bool esCotizacion = false,
  }) =>
      OrdenMantenimiento(
        numeroOrden: 'OT-00014',
        clienteId: cliente.id,
        vehiculoId: vehiculo.id,
        tipoServicio: 'Mantenimiento',
        kilometrajeIngreso: 15000,
        estado: EstadoOrden.listaParaEntrega,
        costoManoObra: costoManoObra,
        esCotizacion: esCotizacion,
      );

  OrdenItem repuesto(String nombre, int cantidad, double precio,
          {double descuento = 0}) =>
      OrdenItem(
        ordenId: 'o1',
        repuestoId: 'rep-${nombre.hashCode}',
        descripcion: nombre,
        cantidad: cantidad,
        precioUnitario: precio,
        descuento: descuento,
      );

  OrdenItem manoObra(String concepto, double monto) => OrdenItem(
        ordenId: 'o1',
        repuestoId: ReglasOrden.idManoObra,
        descripcion: concepto,
        cantidad: 1,
        precioUnitario: monto,
      );

  Future<void> montar(
    WidgetTester tester,
    OrdenMantenimiento o,
    List<OrdenItem> items,
  ) async {
    tester.view.physicalSize = const Size(1000, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<TallerProvider>.value(
        value: tallerProvider,
        child: MaterialApp(
          home: Scaffold(
            body: FacturaPreviewSheet(
              orden: o,
              cliente: cliente,
              vehiculo: vehiculo,
              items: items,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String pesos(double valor) => CurrencyFormatter.format(valor);

  testWidgets('el IVA grava la mano de obra y no los repuestos (OT-00014)',
      (tester) async {
    configurarTaller(19);
    await montar(
      tester,
      orden(costoManoObra: 250000),
      [
        repuesto('Bomba de aceite nkd', 1, 850000),
        manoObra('Mano de obra: Cambio de guaya', 250000),
      ],
    );

    expect(find.text('Subtotal repuestos (IVA incl.)'), findsOneWidget);
    expect(find.text(pesos(850000)), findsOneWidget);
    expect(find.text('IVA 19.0% (mano de obra)'), findsOneWidget);
    expect(find.text(pesos(47500)), findsOneWidget);
    expect(find.text(pesos(1147500)), findsOneWidget);

    // Si el ítem de mano de obra se contara como repuesto, el subtotal sería
    // 1.100.000 y el total 1.397.500: se cobraría la mano de obra dos veces.
    expect(find.text(pesos(1100000)), findsNothing);
    expect(find.text(pesos(1397500)), findsNothing);
  });

  testWidgets('sin IVA configurado no aparece la línea del impuesto',
      (tester) async {
    configurarTaller(0);
    await montar(
      tester,
      orden(costoManoObra: 250000),
      [
        repuesto('Bomba de aceite nkd', 1, 850000),
        manoObra('Mano de obra: Cambio de guaya', 250000),
      ],
    );

    expect(find.text('Subtotal repuestos'), findsOneWidget);
    expect(find.textContaining('IVA'), findsNothing);
    expect(find.text(pesos(1100000)), findsOneWidget); // total sin impuesto
  });

  testWidgets('el descuento de una línea baja el total', (tester) async {
    configurarTaller(0);
    // 2 × 100.000 con 10% de descuento = 180.000. Si alguien recalculara
    // cantidad × precio a mano —el bug que apareció cuatro veces en
    // database_helper— saldrían 200.000.
    await montar(tester, orden(), [repuesto('Cadena', 2, 100000, descuento: 10)]);

    // Dos veces: el subtotal de repuestos y el TOTAL, que aquí coinciden
    // porque no hay mano de obra ni impuesto.
    expect(find.text(pesos(180000)), findsNWidgets(2));
    expect(find.text(pesos(200000)), findsNothing);
  });

  testWidgets('una cotización se anuncia como tal, no como factura',
      (tester) async {
    configurarTaller(19);
    await montar(tester, orden(esCotizacion: true), [
      repuesto('Bomba de aceite nkd', 1, 850000),
    ]);

    expect(find.text('Cotización'), findsOneWidget);
    expect(find.text('Factura de servicio'), findsOneWidget); // solo el título
  });

  testWidgets('sin ítems lo dice en vez de mostrar un hueco', (tester) async {
    configurarTaller(19);
    await montar(tester, orden(), const []);

    expect(find.text('Sin items registrados'), findsOneWidget);
    expect(find.text(pesos(0)), findsWidgets);
  });

  testWidgets('la cabecera lleva el nombre del taller y los datos de la moto',
      (tester) async {
    configurarTaller(19);
    await montar(tester, orden(), [repuesto('Cadena', 1, 95000)]);

    expect(find.text('JP.RACING.315'), findsOneWidget);
    expect(find.text('OT-00014'), findsOneWidget);
    expect(find.text('Cliente: Johan Parada'), findsOneWidget);
    expect(find.text('Vehículo: AKT NKD 125 - CLA87A'), findsOneWidget);
  });
}
