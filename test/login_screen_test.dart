import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:moto_taller_app/data/providers/auth_provider.dart';
import 'package:moto_taller_app/ui/screens/login_screen.dart';

/// La puerta de entrada.
///
/// No se prueba el inicio de sesión de verdad —eso vive en Supabase y no tiene
/// sentido simularlo aquí—, sino que la pantalla ofrezca lo que debe y cambie
/// bien entre entrar y registrarse.
void main() {
  late AuthProvider authProvider;

  setUp(() {
    authProvider = AuthProvider();
  });

  Future<void> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ChangeNotifierProvider<AuthProvider>.value(
        value: authProvider,
        child: MaterialApp(
          // La tarjeta del login está limitada a 440 px de ancho, así que aquí
          // no basta con agrandar la ventana: la fuente de `flutter_test`
          // dibuja cada carácter como un cuadrado del alto de la letra y no
          // cabe de ninguna manera. Se encoge la escala del texto para que las
          // medidas se parezcan a las reales. Otra prueba de que **estas
          // pruebas no dicen nada de cómo se ve la pantalla**.
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(0.5)),
            child: child!,
          ),
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('arranca en modo «ingresar»', (tester) async {
    await montar(tester);

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('INGRESAR'), findsOneWidget);
    expect(find.text('CREAR CUENTA'), findsNothing);
    expect(find.text('¿Sin cuenta? Regístrate'), findsOneWidget);
  });

  testWidgets('ofrece entrar con Google', (tester) async {
    // Es como entran todos los usuarios reales del taller: por eso la
    // advertencia de contraseñas filtradas del panel de Supabase no aplica.
    await montar(tester);

    expect(find.text('Continuar con Google'), findsOneWidget);
  });

  testWidgets('el enlace de abajo alterna entre entrar y registrarse',
      (tester) async {
    await montar(tester);

    await tester.tap(find.text('¿Sin cuenta? Regístrate'));
    await tester.pumpAndSettle();

    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.text('CREAR CUENTA'), findsOneWidget);
    expect(find.text('¿Ya tienes cuenta? Ingresa'), findsOneWidget);

    await tester.tap(find.text('¿Ya tienes cuenta? Ingresa'));
    await tester.pumpAndSettle();

    expect(find.text('Bienvenido de nuevo'), findsOneWidget);
    expect(find.text('INGRESAR'), findsOneWidget);
  });

  testWidgets('la contraseña se escribe tapada y se puede destapar',
      (tester) async {
    await montar(tester);

    final campos = find.byType(TextField);
    expect(campos, findsNWidgets(2));

    expect(tester.widget<TextField>(campos.at(1)).obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_outlined));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(campos.at(1)).obscureText, isFalse);
  });

  testWidgets('un error de autenticación se muestra en pantalla',
      (tester) async {
    // No se traga: durante meses el problema de este proyecto fue justamente
    // que los errores no llegaban a la pantalla.
    await montar(tester);
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
  });
}
