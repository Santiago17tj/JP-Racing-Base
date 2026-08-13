import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:web/web.dart' as web;

/// Implementación web de los ayudantes de URL.
///
/// Hace falta para el inicio de sesión con Google: Supabase devuelve el token
/// en el fragmento de la URL (`#access_token=...`) y hay que leerlo y luego
/// borrarlo para que no quede a la vista ni en el historial.
class WebUrlHelper {
  static String getHash() => web.window.location.hash;

  static void clearHash() {
    try {
      web.window.history.replaceState(null, '', '/');
    } catch (_) {
      // Algunos navegadores lo bloquean en contextos concretos; no es crítico.
    }
  }

  static void configureUrlStrategy() {
    usePathUrlStrategy();
  }
}
