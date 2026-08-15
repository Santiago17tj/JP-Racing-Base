import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moto_taller_app/data/models/perfil_taller.dart';
import 'package:moto_taller_app/data/providers/auth_provider.dart';
import 'package:moto_taller_app/data/providers/sesion_local_provider.dart';
import 'package:moto_taller_app/data/providers/taller_provider.dart';
import 'package:moto_taller_app/ui/screens/ajustes_taller_screen.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// Ajustes del taller. Aquí vive **el porcentaje de IVA**, que es el número que
/// alimenta el total de todas las facturas: si se guarda mal, se cobra mal en
/// toda la app.
///
/// Como en las demás pruebas de pantalla, el tamaño de la ventana está puesto
/// para que quepa la fuente de `flutter_test` (que dibuja cada carácter como un
/// cuadrado); no dicen nada de cómo se ve.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FuenteDeDatosFalsa db;
  late TallerProvider tallerProvider;
  late SesionLocalProvider sesionProvider;
  late AuthProvider authProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FuenteDeDatosFalsa();
    tallerProvider = TallerProvider(db: db);
    sesionProvider = SesionLocalProvider();
    authProvider = AuthProvider();
  });

  void configurarTaller({
    String nombre = 'JP.RACING.315',
    double impuesto = 0.0,
    String moneda = 'COP',
  }) {
    tallerProvider.setTaller(PerfilTaller(
      usuarioAdministradorId: 'admin',
      nombreTaller: nombre,
      porcentajeImpuestoDefecto: impuesto,
      moneda: moneda,
    ));
  }

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1100, 5000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TallerProvider>.value(value: tallerProvider),
          ChangeNotifierProvider<SesionLocalProvider>.value(
              value: sesionProvider),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(home: AjustesTallerScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> guardar(WidgetTester tester) async {
    final boton =
        find.widgetWithText(ElevatedButton, 'Guardar Configuración del Taller');
    await tester.ensureVisible(boton);
    await tester.pumpAndSettle();
    await tester.tap(boton);
    await tester.pumpAndSettle();
  }

  group('impuesto', () {
    testWidgets('el porcentaje de IVA se guarda tal cual se escribe',
        (tester) async {
      configurarTaller(impuesto: 0);
      await montar(tester);

      await tester.enterText(
          find.widgetWithText(
              TextFormField, 'Impuesto por Defecto (Porcentaje %)'),
          '19');
      await guardar(tester);

      expect(db.perfil, isNotNull);
      expect(db.perfil!.porcentajeImpuestoDefecto, 19.0);
      expect(tallerProvider.taller!.porcentajeImpuestoDefecto, 19.0);
      expect(find.text('Ajustes guardados correctamente'), findsOneWidget);
    });

    testWidgets('el impuesto ya configurado sale escrito al abrir',
        (tester) async {
      configurarTaller(impuesto: 19);
      await montar(tester);

      expect(find.text('19.0'), findsOneWidget);
    });

    testWidgets('un impuesto negativo no se guarda', (tester) async {
      configurarTaller(impuesto: 19);
      await montar(tester);

      await tester.enterText(
          find.widgetWithText(
              TextFormField, 'Impuesto por Defecto (Porcentaje %)'),
          '-5');
      await guardar(tester);

      expect(db.perfil, isNull, reason: 'no debió llegar a guardar');
      expect(find.text('Debe ser un número positivo válido'), findsOneWidget);
      expect(tallerProvider.taller!.porcentajeImpuestoDefecto, 19.0);
    });

    testWidgets('dejar el impuesto vacío lo pone en cero, no lo conserva',
        (tester) async {
      // Comportamiento vigente: el validador deja pasar el campo vacío y
      // `double.tryParse('') ?? 0.0` lo convierte en 0. O sea, borrar el campo
      // **quita el IVA de todas las facturas siguientes**. Queda fijado aquí
      // para que el cambio no pase inadvertido si alguien lo toca.
      configurarTaller(impuesto: 19);
      await montar(tester);

      await tester.enterText(
          find.widgetWithText(
              TextFormField, 'Impuesto por Defecto (Porcentaje %)'),
          '');
      await guardar(tester);

      expect(db.perfil!.porcentajeImpuestoDefecto, 0.0);
    });
  });

  group('datos del taller', () {
    testWidgets('nombre, teléfono, dirección y ciudad se guardan',
        (tester) async {
      configurarTaller();
      await montar(tester);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre del Taller'), 'JP Racing');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Teléfono'), '3150000000');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Dirección'), 'Calle 45 #12-30');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Ciudad / País'), 'Bucaramanga');
      await guardar(tester);

      expect(db.perfil!.nombreTaller, 'JP Racing');
      expect(db.perfil!.telefono, '3150000000');
      expect(db.perfil!.direccion, 'Calle 45 #12-30');
      expect(db.perfil!.ciudad, 'Bucaramanga');
    });

    testWidgets('sin nombre de taller no se guarda nada', (tester) async {
      configurarTaller();
      await montar(tester);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre del Taller'), '');
      await guardar(tester);

      expect(db.perfil, isNull);
      expect(find.text('Este campo es obligatorio'), findsOneWidget);
    });

    testWidgets('el pie de factura se guarda', (tester) async {
      configurarTaller();
      await montar(tester);

      await tester.enterText(
          find.widgetWithText(
              TextFormField, 'Términos y Condiciones (Pie de Factura)'),
          'Garantía de 30 días en mano de obra');
      await guardar(tester);

      expect(db.perfil!.terminosCondicionesFactura,
          'Garantía de 30 días en mano de obra');
    });
  });

  group('modo mecánico', () {
    testWidgets('el administrador ve la sección de finanzas', (tester) async {
      configurarTaller();
      await montar(tester);

      expect(find.text('Finanzas & Flujo de Caja'), findsOneWidget);
      expect(find.text('Pasar a modo mecanico'), findsOneWidget);
    });

    testWidgets('el mecánico no ve la sección de finanzas', (tester) async {
      configurarTaller();
      await sesionProvider.activarModoMecanico();
      await montar(tester);

      expect(find.text('Finanzas & Flujo de Caja'), findsNothing);
      expect(find.text('Abrir Módulo Contable'), findsNothing);
      expect(find.text('Volver a administrador'), findsOneWidget);
    });

    testWidgets('pasar a modo mecánico oculta las finanzas sin recargar',
        (tester) async {
      configurarTaller();
      await montar(tester);

      final boton = find.text('Pasar a modo mecanico');
      await tester.ensureVisible(boton);
      await tester.pumpAndSettle();
      await tester.tap(boton);
      await tester.pumpAndSettle();

      expect(sesionProvider.esAdministrador, isFalse);
      expect(find.text('Finanzas & Flujo de Caja'), findsNothing);
    });

    testWidgets('con PIN puesto, volver a administrador exige el PIN correcto',
        (tester) async {
      configurarTaller();
      await sesionProvider.definirPin('1234');
      await sesionProvider.activarModoMecanico();
      await montar(tester);

      await tester.tap(find.text('Volver a administrador'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)),
          '9999');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pumpAndSettle();

      expect(sesionProvider.esAdministrador, isFalse);
      expect(find.text('PIN incorrecto'), findsOneWidget);
    });

    testWidgets('con el PIN correcto sí vuelve a administrador',
        (tester) async {
      // En una prueba aparte porque los `SnackBar` se encolan: el segundo no
      // aparece hasta que se va el primero, y buscarlo daría un falso fallo.
      configurarTaller();
      await sesionProvider.definirPin('1234');
      await sesionProvider.activarModoMecanico();
      await montar(tester);

      await tester.tap(find.text('Volver a administrador'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.descendant(
              of: find.byType(AlertDialog), matching: find.byType(TextField)),
          '1234');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pumpAndSettle();

      expect(sesionProvider.esAdministrador, isTrue);
      expect(find.text('Modo administrador activo'), findsOneWidget);
      expect(find.text('Finanzas & Flujo de Caja'), findsOneWidget);
    });

    testWidgets('sin PIN puesto vuelve directo, sin pedir nada',
        (tester) async {
      configurarTaller();
      await sesionProvider.activarModoMecanico();
      await montar(tester);

      await tester.tap(find.text('Volver a administrador'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
      await tester.pumpAndSettle();

      expect(sesionProvider.esAdministrador, isTrue);
    });
  });
}
