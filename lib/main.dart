import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'core/config/app_config.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/auth_provider.dart';
import 'data/providers/inventario_provider.dart';
import 'data/providers/ordenes_provider.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Base de datos local (SQLite) ─────────────────────────
  // NOTA: En web, DatabaseHelper usa listas en memoria (no SQLite real).
  // Solo inicializamos sqflite en plataformas nativas (desktop/mobile).
  if (!kIsWeb) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // ── Supabase (cloud) — con manejo de error para no bloquear la app ──
  try {
    await SupabaseService.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
    debugPrint('✅ Supabase conectado: ${AppConfig.supabaseUrl}');
  } catch (e) {
    debugPrint('⚠️ Supabase no disponible — modo offline: $e');
  }

  runApp(const MotoTallerApp());
}

class MotoTallerApp extends StatelessWidget {
  const MotoTallerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => InventarioProvider()),
        ChangeNotifierProvider(create: (_) => OrdenesProvider()),
      ],
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MaterialApp(
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.darkTheme,
            home: auth.isAuthenticated ? const HomeShell() : const LoginScreen(),
          );
        },
      ),
    );
  }
}
