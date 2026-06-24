/// Configuración central de la aplicación.
/// Las credenciales de Supabase son públicas (anon key) — seguras en cliente.
class AppConfig {
  // ── Supabase ────────────────────────────────────────────────────────────
  static const String supabaseUrl = 'https://snzqauzmtydcheryfwmd.supabase.co';
  static const String supabaseAnonKey =
      'sb_publishable_guKJMkQemsuYGvjAhjwSDg_XYsfQtQp';

  // ── App ─────────────────────────────────────────────────────────────────
  static const String appName = 'MotoTaller & Facturación';
  static const String appVersion = '1.0.0';
}
