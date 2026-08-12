import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de diseño centralizado — Estética Invoice Fly Premium.
///
/// Paleta oscura sofisticada con acentos vibrantes.
/// Tipografía Inter para máxima legibilidad en listas de inventario.
class AppTheme {
  AppTheme._();

  // ── Colores Base ──────────────────────────────
  static const Color background = Color(0xFF0B0E14);
  static const Color surface = Color(0xFF151921);
  static const Color surfaceLight = Color(0xFF1E2433);
  static const Color surfaceBorder = Color(0xFF2A3141);

  // ── Colores de Acento ─────────────────────────
  static const Color primary = Color(0xFF3B82F6);
  static const Color primaryLight = Color(0xFF60A5FA);
  static const Color primaryDark = Color(0xFF2563EB);
  static const Color primarySurface = Color(0xFF1E3A5F);

  // ── Colores Semánticos ────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successSurface = Color(0xFF0D3B2E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFF3D2E0A);
  static const Color error = Color(0xFFEF4444);
  static const Color errorSurface = Color(0xFF3D1515);

  // ── Texto ─────────────────────────────────────
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textTertiary = Color(0xFF64748B);
  static const Color textInverse = Color(0xFF0F172A);

  // ── Gradientes ────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF8B5CF6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient scannerGradient = LinearGradient(
    colors: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Gradientes por Estado de Orden ────────────────
  static const List<Color> gradientIngresada = [
    Color(0xFF3B82F6),
    Color(0xFF06B6D4)
  ];
  static const List<Color> gradientDiagnostico = [
    Color(0xFFF59E0B),
    Color(0xFFF97316)
  ];
  static const List<Color> gradientReparacion = [
    Color(0xFFF97316),
    Color(0xFFEF4444)
  ];
  static const List<Color> gradientLista = [
    Color(0xFF10B981),
    Color(0xFF059669)
  ];
  static const List<Color> gradientEntregada = [
    Color(0xFF8B5CF6),
    Color(0xFF6366F1)
  ];

  /// Retorna la lista de colores del gradiente según el estado.
  static List<Color> gradientForEstado(String estadoValue) {
    final val = estadoValue.trim().toLowerCase();
    switch (val) {
      case 'ingresada':
        return gradientIngresada;
      case 'en diagnóstico':
      case 'en_diagnostico':
        return gradientDiagnostico;
      case 'en reparación':
      case 'en_reparacion':
        return gradientReparacion;
      case 'lista para entrega':
      case 'lista_para_entrega':
        return gradientLista;
      case 'entregada':
        return gradientEntregada;
      default:
        return gradientIngresada;
    }
  }

  // ── Radios ────────────────────────────────────
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;

  // ── Espaciado ─────────────────────────────────
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // ── Sombras ───────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.3),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
      ];

  // ── Decoraciones Reutilizables ────────────────
  // Las tarjetas llevan un degradado muy leve y una sombra suave: sobre un
  // fondo oscuro plano, un relleno de un solo tono las hace desaparecer.
  static BoxDecoration get cardDecoration => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            surface,
            Color.lerp(surface, surfaceLight, 0.45) ?? surface,
          ],
        ),
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: surfaceBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(surface, surfaceLight, 0.25) ?? surface,
            surface,
          ],
        ),
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: surfaceBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: primary.withValues(alpha: 0.06),
            blurRadius: 30,
            offset: const Offset(0, 2),
          ),
        ],
      );

  /// Glassmorphic card decoration for premium overlays.
  static BoxDecoration glassDecoration({
    double opacity = 0.08,
    double borderOpacity = 0.2,
    double radius = 24,
  }) =>
      BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: Colors.white.withValues(alpha: borderOpacity),
          width: 1.2,
        ),
      );

  // ── Theme Data ────────────────────────────────
  static ThemeData get darkTheme {
    final base = GoogleFonts.interTextTheme().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    // Títulos ligeramente más apretados: en tipografías geométricas como Inter
    // el interletrado por defecto se ve suelto en encabezados grandes.
    final textTheme = base.copyWith(
      headlineLarge: base.headlineLarge?.copyWith(letterSpacing: -0.5),
      headlineMedium: base.headlineMedium?.copyWith(letterSpacing: -0.4),
      titleLarge: base.titleLarge?.copyWith(letterSpacing: -0.3),
      titleMedium: base.titleMedium?.copyWith(letterSpacing: -0.2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryLight,
        surface: surface,
        error: error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background.withValues(alpha: 0.85),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: textPrimary,
          fontSize: 20,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: surfaceBorder, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceLight,
        selectedColor: primarySurface,
        labelStyle: textTheme.bodySmall?.copyWith(color: textSecondary),
        side: const BorderSide(color: surfaceBorder, width: 1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLight,
        hintStyle: textTheme.bodyMedium?.copyWith(color: textTertiary),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingSm + 4,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: surfaceBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      // Botones consistentes en toda la app: misma altura, mismo radio y
      // suficiente área de toque para usarlos con guantes en el taller.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: surfaceLight,
          disabledForegroundColor: textTertiary,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: spacingMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          minimumSize: const Size(0, 46),
          side: const BorderSide(color: surfaceBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: primaryLight,
        unselectedLabelColor: textTertiary,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
        labelStyle: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        unselectedLabelStyle: textTheme.titleSmall,
      ),
      dividerTheme: const DividerThemeData(
        color: surfaceBorder,
        thickness: 1,
        space: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryLight,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLight,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: surfaceBorder),
        ),
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(spacingMd),
        elevation: 6,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        dragHandleColor: textTertiary,
        showDragHandle: true,
      ),
    );
  }
}
