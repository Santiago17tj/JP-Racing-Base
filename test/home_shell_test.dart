import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moto_taller_app/data/models/perfil_taller.dart';
import 'package:moto_taller_app/data/providers/auth_provider.dart';
import 'package:moto_taller_app/data/providers/inventario_provider.dart';
import 'package:moto_taller_app/data/providers/ordenes_provider.dart';
import 'package:moto_taller_app/data/providers/sesion_local_provider.dart';
import 'package:moto_taller_app/data/providers/taller_provider.dart';
import 'package:moto_taller_app/ui/screens/home_shell.dart';
import 'package:moto_taller_app/ui/screens/inventario_screen.dart';
import 'package:moto_taller_app/ui/screens/ordenes_activas_screen.dart';

import 'ayudas/fuente_de_datos_falsa.dart';

/// El contenedor con la barra de abajo.
///
/// Lo que importa aquí es el **portero**: hasta que el perfil del taller no
/// está cargado no se entra al tablero. Sin ese bloqueo la app arrancaba con
/// datos vacíos y el usuario creía que había perdido su trabajo.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FuenteDeDatosFalsa db;
  late OrdenesProvider ordenesProvider;
  late InventarioProvider inventarioProvider;
  late TallerProvider tallerProvider;
  late SesionLocalProvider sesionProvider;
  late AuthProvider authProvider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = FuenteDeDatosFalsa();
    ordenesProvider = OrdenesProvider(db: db);
    inventarioProvider = InventarioProvider(db: db);
    tallerProvider = TallerProvider(db: db);
    sesionProvider = SesionLocalProvider();
    authProvider = AuthProvider();
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
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
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mientras no haya perfil del taller no se entra al tablero',
      (tester) async {
    // Sin `pumpAndSettle`: se mira el primer fotograma, cuando el perfil
    // todavía no ha llegado. Ese es el momento que el portero protege — antes
    // de que existiera, la app entraba con las listas vacías y el taller creía
    // haber perdido su trabajo.
    tester.view.physicalSize = const Size(1400, 2400);
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
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ],
        child: const MaterialApp(home: HomeShell()),
      ),
    );

    expect(find.text('Cargando perfil del taller...'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsNothing);
    expect(find.byType(OrdenesActivasScreen, skipOffstage: false), findsNothing);

    await tester.pumpAndSettle();
  });

  testWidgets('con el perfil cargado se ven las cuatro secciones',
      (tester) async {
    tallerProvider.setTaller(PerfilTaller(
      usuarioAdministradorId: 'admin',
      nombreTaller: 'JP.RACING.315',
    ));
    await montar(tester);

    expect(find.text('Cargando perfil del taller...'), findsNothing);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.text('Servicios'), findsOneWidget);
    expect(find.text('Inventario'), findsOneWidget);
    expect(find.text('Cloud'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('arranca en Servicios', (tester) async {
    tallerProvider.setTaller(PerfilTaller(
      usuarioAdministradorId: 'admin',
      nombreTaller: 'JP.RACING.315',
    ));
    await montar(tester);

    expect(find.text('Taller & Servicios'), findsOneWidget);
  });

  testWidgets('cambiar de pestaña no destruye la anterior', (tester) async {
    // Van en un `IndexedStack`: las cuatro pantallas siguen vivas, así que al
    // volver no se recarga nada ni se pierde lo escrito.
    tallerProvider.setTaller(PerfilTaller(
      usuarioAdministradorId: 'admin',
      nombreTaller: 'JP.RACING.315',
    ));
    await montar(tester);

    await tester.tap(find.text('Inventario'));
    await tester.pumpAndSettle();

    expect(find.byType(InventarioScreen), findsOneWidget);
    // `skipOffstage: false` porque el `IndexedStack` deja fuera de escena las
    // pantallas que no se ven — pero las conserva montadas, que es justo lo
    // que se quiere comprobar.
    expect(find.byType(OrdenesActivasScreen, skipOffstage: false),
        findsOneWidget,
        reason: 'sigue montada aunque no se vea');
  });
}
