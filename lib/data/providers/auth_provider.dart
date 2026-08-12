import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/supabase_service.dart';
import '../../ui/screens/home_shell.dart';

class AuthProvider extends ChangeNotifier {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static void Function()? onResetAllData;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Si Supabase no está configurado, se muestra la HomeShell directamente
  // (modo offline — sin login requerido)
  bool _isAuthenticated = !SupabaseService.isConfigured;
  bool get isAuthenticated => _isAuthenticated;

  AuthProvider({Session? initialSession}) {
    if (initialSession != null) {
      _isAuthenticated = true;
    }
    _init(initialSession: initialSession);
  }

  void _init({Session? initialSession}) {
    if (SupabaseService.isConfigured) {
      try {
        _isAuthenticated = initialSession != null || SupabaseService.client.auth.currentUser != null;
      } catch (e) {
        debugPrint('❌ Error al comprobar usuario actual inicial: $e');
      }

      try {
        SupabaseService.client.auth.onAuthStateChange.listen((data) {
          bool shouldRedirect = false;
          try {
            final AuthChangeEvent event = data.event;
            final Session? session = data.session;

            // Capturar signedIn, initialSession y tokenRefreshed para cubrir
            // el flujo OAuth donde Supabase devuelve el token vía fragmento de URL.
            final esEventoDeLogin = event == AuthChangeEvent.signedIn ||
                event == AuthChangeEvent.initialSession ||
                event == AuthChangeEvent.tokenRefreshed;

            if (esEventoDeLogin && session != null) {
              onResetAllData?.call(); // Resetear caché de proveedores principales
              _error = null; // Limpiar cualquier error previo de UI
              _isLoading = false;
              if (!_isAuthenticated) {
                _isAuthenticated = true;
              }
              shouldRedirect = true;
            } else if (event == AuthChangeEvent.signedOut) {
              onResetAllData?.call(); // Resetear caché de proveedores principales al salir
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  if (_isAuthenticated) {
                    _isAuthenticated = false;
                    notifyListeners();
                  }
                } catch (routingError) {
                  debugPrint('❌ Error al enrutar en Web (salida): $routingError');
                }
              });
            }
          } catch (streamError) {
            debugPrint('❌ Error al procesar evento de AuthState: $streamError');
            // Si ocurre un error de parsing pero tenemos usuario actual, intentamos redirigir
            if (SupabaseService.client.auth.currentUser != null) {
              _isAuthenticated = true;
              shouldRedirect = true;
            }
          } finally {
            if (shouldRedirect) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                try {
                  notifyListeners();
                } catch (e) {
                  debugPrint('⚠️ Excepción no fatal en notifyListeners de AuthProvider: $e');
                }

                try {
                  if (kIsWeb) {
                    navigatorKey.currentState?.pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeShell()),
                      (route) => false,
                    );
                  }
                } catch (routingError) {
                  debugPrint('❌ Error crítico de enrutamiento en Web: $routingError');
                }
              });
            }
          }
        }, onError: (error) {
          debugPrint('❌ Error en el stream de onAuthStateChange: $error');
          // En caso de error en el stream (ej. triggers de BD fallando),
          // si ya tenemos el token del usuario en memoria, forzamos la redirección.
          if (SupabaseService.client.auth.currentUser != null) {
            _isAuthenticated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              try {
                notifyListeners();
              } catch (_) {}
              try {
                if (kIsWeb) {
                  navigatorKey.currentState?.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const HomeShell()),
                    (route) => false,
                  );
                }
              } catch (_) {}
            });
          }
        });
      } catch (e) {
        debugPrint('❌ Error general en listener de Auth: $e');
      }
    }
  }

  String? _error;
  String? get error => _error;

  String? get currentUserId {
    if (!SupabaseService.isConfigured || SupabaseService.client.auth.currentUser == null) {
      return 'demo-user';
    }
    return SupabaseService.client.auth.currentUser?.id;
  }

  Future<void> signIn({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await SupabaseService.signInWithEmail(email: email, password: password);
      _isAuthenticated = true;
    } catch (e) {
      _error = _parseError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signUp({required String email, required String password}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await SupabaseService.signUpWithEmail(email: email, password: password);
      _isAuthenticated = true;
    } catch (e) {
      _error = _parseError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signInWithGoogle() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (SupabaseService.isConfigured) {
        if (kIsWeb) {
          const String projectUrl = 'https://snzqauzmtydcheryfwmd.supabase.co';
          const String redirectTo = 'http://localhost:8080';

          // Construcción segura con QueryParameters para auto-codificar la URL
          final Uri googleAuthUrl = Uri.parse('$projectUrl/auth/v1/authorize').replace(
            queryParameters: {
              'provider': 'google',
              'redirect_to': redirectTo,
            },
          );

          if (await canLaunchUrl(googleAuthUrl)) {
            await launchUrl(googleAuthUrl, webOnlyWindowName: '_self');
            // En Web, la app navega fuera de la página hacia Google.
            // NO reseteamos isLoading aquí porque el usuario está siendo redirigido.
            // El estado se actualizará cuando Supabase dispare onAuthStateChange
            // al regresar con el access_token en la URL.
            return;
          } else {
            throw 'No se pudo lanzar la URL de autenticación';
          }
        } else {
          await SupabaseService.client.auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: 'io.supabase.mototaller://login-callback',
          );
        }
      } else {
        _isAuthenticated = true;
      }
    } catch (e) {
      debugPrint('❌ Error crítico en Google Auth: $e');
      _error = _parseError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    try {
      await SupabaseService.signOut();
    } catch (_) {}
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Permite ingresar a la aplicación en modo demo sin cuenta de Supabase.
  void bypassAuthentication() {
    _isAuthenticated = true;
    notifyListeners();
  }

  /// Limpia el error manualmente (para UX)
  void clearError() {
    _error = null;
    notifyListeners();
  }

  String _parseError(String raw) {
    if (raw.contains('Invalid login credentials')) return 'Correo o contraseña incorrectos';
    if (raw.contains('Email not confirmed')) return 'Confirma tu email antes de ingresar';
    if (raw.contains('User already registered')) return 'Este correo ya tiene una cuenta';
    if (raw.contains('network') || raw.contains('SocketException')) return 'Sin conexión a internet';
    return 'Error: ${raw.replaceAll('Exception: ', '')}';
  }
}
