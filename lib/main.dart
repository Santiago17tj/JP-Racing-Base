import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/app_config.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/taller_provider.dart';
import 'data/providers/inventario_provider.dart';
import 'data/providers/ordenes_provider.dart';
import 'data/providers/sesion_local_provider.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/login_screen.dart';
import 'core/services/web_url_helper_stub.dart'
    if (dart.library.html) 'core/services/web_url_helper_web.dart';

/// Soporta scroll de arrastre mediante mouse y trackpad en Web y Desktop.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

Future<void> main() async {
  // En la app publicada no se escribe nada en la consola del sistema: los
  // mensajes de depuración incluyen datos de clientes, órdenes y respuestas de
  // Supabase, y cualquiera con el teléfono conectado podría leerlos.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  WebUrlHelper.configureUrlStrategy();
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    // Filtro estricto: FFI SOLO para computadoras. Android e iOS NO entran aquí.
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      debugPrint('🖥️ SQLite FFI inicializado en Escritorio');
    }
  }

  // ── Supabase (cloud) — con manejo de error para no bloquear la app ──
  Session? initialSession;
  try {
    await SupabaseService.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    debugPrint('✅ Supabase conectado: ${AppConfig.supabaseUrl}');

    // 2. Retraso Técnico: Permite al SDK extraer el #access_token de la URL en Web
    if (kIsWeb) {
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // 3. Captura la sesión ya procesada
    initialSession = SupabaseService.client.auth.currentSession;
    debugPrint('🌐 Sesión digerida en main(): ${initialSession != null}');

    // 4. BYPASS MANUAL PARA WEB: Si el SDK no procesó el hash, extraemos el token a la fuerza
    if (kIsWeb && initialSession == null) {
      final String hash = WebUrlHelper.getHash();
      if (hash.contains('access_token=')) {
        try {
          debugPrint('🌐 Detectado Hash OAuth residual en Web. Forzando extracción manual...');
          // Removemos el '#' inicial para poder parsear
          final String normalizados = hash.startsWith('#') ? hash.substring(1) : hash;
          final Map<String, String> params = Uri.splitQueryString(normalizados);
          
          final String? accessToken = params['access_token'];
          final String? refreshToken = params['refresh_token'];

          if (accessToken != null && refreshToken != null) {
            debugPrint('🔄 Intercambiando tokens de forma correcta en la Web...');
            
            // CORRECCIÓN: Pasamos el refresh_token para restaurar la sesión de forma legal en el SDK
            final AuthResponse res = await SupabaseService.client.auth.setSession(refreshToken);
            
            // Limpiamos la URL de inmediato para evitar re-procesamientos al refrescar
            WebUrlHelper.clearHash();

            initialSession = res.session;
            debugPrint('✅ Sesión recuperada exitosamente vía Bypass Manual: ${initialSession != null}');
          }
        } catch (e) {
          debugPrint('🚨 Error en intercambio: $e');
        }
      }
    }
  } catch (e) {
    debugPrint('⚠️ Supabase no disponible — modo offline: $e');
  }

  // ── Manejo Global de Errores para Debug en Web ────────────────
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    _mostrarErrorGlobal('FlutterError: ${details.exception}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    _mostrarErrorGlobal('AsyncError: $error\n$stack');
    return true;
  };

  runApp(MotoTallerApp(initialSession: initialSession));
}

void _mostrarErrorGlobal(String mensaje) {
  debugPrint(mensaje);
  // Intentar mostrar en el DOM si estamos en Web para no depender de consola minificada
  if (kIsWeb) {
    try {
      // Usar js_interop o ignore
      // ignore: avoid_web_libraries_in_flutter
      // import 'dart:html' no está, así que imprimimos fuerte
    } catch (_) {}
  }
}

class MotoTallerApp extends StatelessWidget {
  final Session? initialSession;

  final AuthProvider authProvider;
  final TallerProvider tallerProvider;
  final InventarioProvider inventarioProvider;
  final OrdenesProvider ordenesProvider;
  final SesionLocalProvider sesionLocalProvider;

  MotoTallerApp({super.key, this.initialSession})
      : authProvider = AuthProvider(initialSession: initialSession),
        tallerProvider = TallerProvider(),
        inventarioProvider = InventarioProvider(),
        ordenesProvider = OrdenesProvider(),
        sesionLocalProvider = SesionLocalProvider() {
    // El modo de trabajo se lee del propio teléfono al arrancar.
    sesionLocalProvider.cargar();
    // Vincular la limpieza de datos entre sesiones para evitar State Leakage
    AuthProvider.onResetAllData = () {
      tallerProvider.limpiarDatos();
      inventarioProvider.limpiarDatos();
      ordenesProvider.limpiarDatos();
    };
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: tallerProvider),
        ChangeNotifierProvider.value(value: inventarioProvider),
        ChangeNotifierProvider.value(value: ordenesProvider),
        ChangeNotifierProvider.value(value: sesionLocalProvider),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          if (kDebugMode || kIsWeb) {
            print('🌐 Estado actual de autenticación en el Router: ${auth.isAuthenticated}');
          }
          return MaterialApp(
            title: AppConfig.appName,
            navigatorKey: AuthProvider.navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            scrollBehavior: AppScrollBehavior(),
            home: auth.isAuthenticated ? const HomeShell() : const LoginScreen(),
            onGenerateRoute: (settings) {
              // Si la ruta contiene access_token (de retorno de Supabase OAuth), la interceptamos
              if (settings.name != null && (settings.name!.contains('access_token') || settings.name!.contains('error'))) {
                return MaterialPageRoute(
                  builder: (context) {
                    final auth = Provider.of<AuthProvider>(context);
                    if (kDebugMode || kIsWeb) {
                      print('🌐 Interceptada ruta OAuth en Web: ${settings.name}');
                      print('🌐 Estado de autenticación en ruta interceptada: ${auth.isAuthenticated}');
                    }
                    if (auth.isAuthenticated) {
                      return const HomeShell();
                    } else {
                      return Scaffold(
                        backgroundColor: AppTheme.darkTheme.scaffoldBackgroundColor,
                        body: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(
                                color: AppTheme.primaryLight,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Procesando inicio de sesión...',
                                style: TextStyle(
                                  color: AppTheme.darkTheme.textTheme.bodyMedium?.color ?? Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                  },
                );
              }
              return null;
            },
          );
        },
      ),
    );
  }
}
