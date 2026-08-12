/// Configuración central de la aplicación.
/// Las credenciales de Supabase son públicas (anon key) — seguras en cliente.
class AppConfig {
  // ── Supabase ────────────────────────────────────────────────────────────
  static const String supabaseUrl = 'https://snzqauzmtydcheryfwmd.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_guKJMkQemsuYGvjAhjwSDg_XYsfQtQp';

  // ── App ─────────────────────────────────────────────────────────────────
  static const String appName = 'MotoTaller & Facturación';
  static const String appVersion = '1.4.3';

  // ── Facturación Electrónica (Factus DIAN Sandbox) ────────────────────────
  /// Desactivada por defecto para no interferir con el flujo normal.
  static const bool facturacionElectronicaActiva = false;
  static const String factusApiUrl = 'https://api-sandbox.factus.com.co';

  /// El token nunca debe quedar escrito en el código: se inyecta al compilar
  /// con `flutter build apk --dart-define=FACTUS_TOKEN=...`. Así no viaja al
  /// repositorio ni queda dentro del APK de quien no lo necesite.
  static const String factusAccessToken =
      String.fromEnvironment('FACTUS_TOKEN', defaultValue: '');
}

