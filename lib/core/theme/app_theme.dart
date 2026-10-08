import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Sistema de diseño de Mecanix: estética de taller.
///
/// Grafito neutro (no azul marino) con un naranja de competición como único
/// acento, tipografía condensada de rotulación para títulos y cifras, y
/// superficies planas con borde fino: sin degradados ni resplandores.
///
/// El naranja de relleno ([primary]) es más oscuro que el de texto
/// ([primaryLight]) a propósito: con texto blanco encima da 4,5:1, y el claro
/// se lee bien sobre el fondo oscuro. No intercambiarlos.
class AppTheme {
  AppTheme._();

  // ── Colores Base ──────────────────────────────
  static const Color background = Color(0xFF0F1012);
  static const Color surface = Color(0xFF18191C);
  static const Color surfaceLight = Color(0xFF222428);
  static const Color surfaceBorder = Color(0xFF2E3136);

  // ── Colores de Acento ─────────────────────────
  static const Color primary = Color(0xFFC8500E);
  static const Color primaryLight = Color(0xFFFF8A45);
  static const Color primaryDark = Color(0xFFA3410B);
  static const Color primarySurface = Color(0xFF33200F);

  // ── Colores Semánticos ────────────────────────
  static const Color success = Color(0xFF2FBF71);
  static const Color successSurface = Color(0xFF11301F);
  static const Color warning = Color(0xFFF5B82E);
  static const Color warningSurface = Color(0xFF3A2D0D);
  static const Color error = Color(0xFFF0524F);
  static const Color errorSurface = Color(0xFF3B1716);

  // ── Texto ─────────────────────────────────────
  static const Color textPrimary = Color(0xFFF4F2EE);
  static const Color textSecondary = Color(0xFFA9ABAE);
  static const Color textTertiary = Color(0xFF75787D);
  static const Color textInverse = Color(0xFF111111);

  // ── Degradados ────────────────────────────────
  // Se conservan los nombres porque varias pantallas los usan, pero ya no
  // mezclan tonos: son el mismo naranja con un poco de profundidad.
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient scannerGradient = primaryGradient;

  // ── Colores por Estado de Orden ───────────────────
  static const Color colorIngresada = Color(0xFF5B8DEF);
  static const Color colorDiagnostico = Color(0xFFF5B82E);
  static const Color colorReparacion = Color(0xFFFF8A45);
  static const Color colorLista = Color(0xFF2FBF71);
  static const Color colorEntregada = Color(0xFF8A8F98);

  static const List<Color> gradientIngresada = [colorIngresada, colorIngresada];
  static const List<Color> gradientDiagnostico = [
    colorDiagnostico,
    colorDiagnostico
  ];
  static const List<Color> gradientReparacion = [
    colorReparacion,
    colorReparacion
  ];
  static const List<Color> gradientLista = [colorLista, colorLista];
  static const List<Color> gradientEntregada = [colorEntregada, colorEntregada];

  /// Colores del estado (dos iguales: el estado se pinta plano).
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
  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 14.0;
  static const double radiusXl = 20.0;

  // ── Espaciado ─────────────────────────────────
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // ── Sombras ───────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.25),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get elevatedShadow => cardShadow;

  // ── Decoraciones Reutilizables ────────────────
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: surfaceBorder, width: 1),
      );

  static BoxDecoration get elevatedCardDecoration => BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radiusLg),
        border: Border.all(color: surfaceBorder, width: 1),
        boxShadow: cardShadow,
      );

  static BoxDecoration glassDecoration({
    double opacity = 0.08,
    double borderOpacity = 0.2,
    double radius = 20,
  }) =>
      BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: surfaceBorder, width: 1),
      );

  // ── Theme Data ────────────────────────────────
  static ThemeData get darkTheme {
    final cuerpo = GoogleFonts.barlowTextTheme().apply(
      bodyColor: textPrimary,
      displayColor: textPrimary,
    );
    // Títulos, pestañas y botones en la condensada: se lee como la rotulación
    // de un taller y deja caber más en una pantalla de 360 px.
    TextStyle? condensada(TextStyle? base, FontWeight peso,
            {double espaciado = 0}) =>
        GoogleFonts.barlowCondensed(textStyle: base).copyWith(
          fontWeight: peso,
          letterSpacing: espaciado,
        );
    final textTheme = cuerpo.copyWith(
      displayLarge: condensada(cuerpo.displayLarge, FontWeight.w700),
      displayMedium: condensada(cuerpo.displayMedium, FontWeight.w700),
      displaySmall: condensada(cuerpo.displaySmall, FontWeight.w700),
      headlineLarge: condensada(cuerpo.headlineLarge, FontWeight.w700),
      headlineMedium: condensada(cuerpo.headlineMedium, FontWeight.w700),
      headlineSmall: condensada(cuerpo.headlineSmall, FontWeight.w700),
      titleLarge: condensada(cuerpo.titleLarge, FontWeight.w700),
      titleMedium: condensada(cuerpo.titleMedium, FontWeight.w600,
          espaciado: 0.2),
      titleSmall:
          condensada(cuerpo.titleSmall, FontWeight.w600, espaciado: 0.3),
      labelLarge:
          condensada(cuerpo.labelLarge, FontWeight.w700, espaciado: 0.6),
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
        onSecondary: textInverse,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: spacingMd,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: textPrimary,
          fontSize: 25,
          letterSpacing: 0.2,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
        actionsIconTheme: const IconThemeData(color: textSecondary),
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
        labelStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
        floatingLabelStyle:
            textTheme.bodyMedium?.copyWith(color: primaryLight),
        prefixIconColor: textTertiary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacingMd,
          vertical: spacingSm + 6,
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
          borderSide: const BorderSide(color: primaryLight, width: 1.5),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 2,
        highlightElevation: 4,
        extendedTextStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
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
          minimumSize: const Size(0, 50),
          padding: const EdgeInsets.symmetric(horizontal: spacingMd),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryLight,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: surfaceBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryLight,
          minimumSize: const Size(0, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: textTheme.labelLarge?.copyWith(fontSize: 15),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: textSecondary),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textTertiary,
        indicatorColor: primaryLight,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: surfaceBorder,
        labelStyle: textTheme.titleSmall?.copyWith(fontSize: 17),
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(fontSize: 17),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primaryLight,
        unselectedItemColor: textTertiary,
        elevation: 0,
        selectedLabelStyle: textTheme.titleSmall?.copyWith(fontSize: 13),
        unselectedLabelStyle: textTheme.titleSmall?.copyWith(fontSize: 13),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? Colors.white : textTertiary),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? primary : surfaceLight),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected) ? primary : surfaceBorder),
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
        elevation: 2,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontSize: 22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: surfaceBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
        dragHandleColor: textTertiary,
        showDragHandle: true,
      ),
    );
  }
}
