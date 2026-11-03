import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Semantic colors for the four nutrition metrics. Kept as a ThemeExtension so
/// both light and dark themes can be animated and tested independently.
@immutable
final class MacroColors extends ThemeExtension<MacroColors> {
  const MacroColors({
    required this.calories,
    required this.caloriesContainer,
    required this.protein,
    required this.proteinContainer,
    required this.carbohydrates,
    required this.carbohydratesContainer,
    required this.fat,
    required this.fatContainer,
  });

  final Color calories;
  final Color caloriesContainer;
  final Color protein;
  final Color proteinContainer;
  final Color carbohydrates;
  final Color carbohydratesContainer;
  final Color fat;
  final Color fatContainer;

  static const MacroColors light = MacroColors(
    calories: Color(0xFF91480D),
    caloriesContainer: Color(0xFFF9E7D5),
    protein: Color(0xFF0C6353),
    proteinContainer: Color(0xFFD2ECE4),
    carbohydrates: Color(0xFF6F5100),
    carbohydratesContainer: Color(0xFFF5E7C3),
    fat: Color(0xFF8E3A31),
    fatContainer: Color(0xFFF6DDD8),
  );

  static const MacroColors dark = MacroColors(
    calories: Color(0xFFF7B57C),
    caloriesContainer: Color(0xFF4A2B0E),
    protein: Color(0xFF7CD9C2),
    proteinContainer: Color(0xFF0D3C32),
    carbohydrates: Color(0xFFE9C56A),
    carbohydratesContainer: Color(0xFF3B2D00),
    fat: Color(0xFFF5AEA3),
    fatContainer: Color(0xFF46201B),
  );

  @override
  MacroColors copyWith({
    Color? calories,
    Color? caloriesContainer,
    Color? protein,
    Color? proteinContainer,
    Color? carbohydrates,
    Color? carbohydratesContainer,
    Color? fat,
    Color? fatContainer,
  }) {
    return MacroColors(
      calories: calories ?? this.calories,
      caloriesContainer: caloriesContainer ?? this.caloriesContainer,
      protein: protein ?? this.protein,
      proteinContainer: proteinContainer ?? this.proteinContainer,
      carbohydrates: carbohydrates ?? this.carbohydrates,
      carbohydratesContainer:
          carbohydratesContainer ?? this.carbohydratesContainer,
      fat: fat ?? this.fat,
      fatContainer: fatContainer ?? this.fatContainer,
    );
  }

  @override
  MacroColors lerp(ThemeExtension<MacroColors>? other, double t) {
    if (other is! MacroColors) return this;
    return MacroColors(
      calories: Color.lerp(calories, other.calories, t)!,
      caloriesContainer: Color.lerp(
        caloriesContainer,
        other.caloriesContainer,
        t,
      )!,
      protein: Color.lerp(protein, other.protein, t)!,
      proteinContainer: Color.lerp(
        proteinContainer,
        other.proteinContainer,
        t,
      )!,
      carbohydrates: Color.lerp(carbohydrates, other.carbohydrates, t)!,
      carbohydratesContainer: Color.lerp(
        carbohydratesContainer,
        other.carbohydratesContainer,
        t,
      )!,
      fat: Color.lerp(fat, other.fat, t)!,
      fatContainer: Color.lerp(fatContainer, other.fatContainer, t)!,
    );
  }
}

/// Central visual language for NutriScan.
///
/// The palette is intentionally calm and health-oriented: deep teal for trust,
/// warm stone surfaces for comfort during long reading sessions, and amber only
/// for development/limitation notices that must stay noticeable without
/// looking like an error.
abstract final class AppTheme {
  static const Color _seed = Color(0xFF155E4F);
  static const Color _stageInk = Color(0xFF07120F);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ColorScheme _scheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final seed = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    );

    if (isDark) {
      return seed.copyWith(
        primary: const Color(0xFF8AD5C3),
        onPrimary: const Color(0xFF00382D),
        primaryContainer: const Color(0xFF0C4F41),
        onPrimaryContainer: const Color(0xFFA9EFDB),
        secondary: const Color(0xFFB4CCC4),
        onSecondary: const Color(0xFF1F352F),
        secondaryContainer: const Color(0xFF354B44),
        onSecondaryContainer: const Color(0xFFD0E8E0),
        tertiary: const Color(0xFFECC06C),
        onTertiary: const Color(0xFF452F00),
        tertiaryContainer: const Color(0xFF493500),
        onTertiaryContainer: const Color(0xFFFFDFA3),
        error: const Color(0xFFFFB4AB),
        onError: const Color(0xFF690005),
        errorContainer: const Color(0xFF93000A),
        onErrorContainer: const Color(0xFFFFDAD6),
        surface: const Color(0xFF111512),
        onSurface: const Color(0xFFE2E4DE),
        onSurfaceVariant: const Color(0xFFC0C8C1),
        surfaceContainerLowest: const Color(0xFF0C100D),
        surfaceContainerLow: const Color(0xFF181D1A),
        surfaceContainer: const Color(0xFF1C211E),
        surfaceContainerHigh: const Color(0xFF262B28),
        surfaceContainerHighest: const Color(0xFF313633),
        outline: const Color(0xFF8A928B),
        outlineVariant: const Color(0xFF414943),
        inverseSurface: const Color(0xFFE2E4DE),
        onInverseSurface: const Color(0xFF2E312D),
        inversePrimary: const Color(0xFF155E4F),
        surfaceTint: const Color(0xFF8AD5C3),
        shadow: Colors.black,
        scrim: Colors.black,
      );
    }

    return seed.copyWith(
      primary: const Color(0xFF155E4F),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFFD3ECE4),
      onPrimaryContainer: const Color(0xFF07382F),
      secondary: const Color(0xFF4D635C),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFFD7E7E1),
      onSecondaryContainer: const Color(0xFF253B35),
      tertiary: const Color(0xFF7A4F00),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFFFCE8C6),
      onTertiaryContainer: const Color(0xFF3C2A00),
      error: const Color(0xFFB3261E),
      onError: Colors.white,
      errorContainer: const Color(0xFFF9DEDC),
      onErrorContainer: const Color(0xFF410E0B),
      surface: const Color(0xFFFCFAF5),
      onSurface: const Color(0xFF1A1C19),
      onSurfaceVariant: const Color(0xFF414943),
      surfaceContainerLowest: const Color(0xFFFFFFFF),
      surfaceContainerLow: const Color(0xFFF7F4ED),
      surfaceContainer: const Color(0xFFF1EEE6),
      surfaceContainerHigh: const Color(0xFFECE8DF),
      surfaceContainerHighest: const Color(0xFFE6E2D8),
      outline: const Color(0xFF747A72),
      outlineVariant: const Color(0xFFC4C9C0),
      inverseSurface: const Color(0xFF2F312D),
      onInverseSurface: const Color(0xFFF2F1EA),
      inversePrimary: const Color(0xFF9BD2C3),
      surfaceTint: const Color(0xFF155E4F),
      shadow: Colors.black,
      scrim: Colors.black,
    );
  }

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme = _scheme(brightness);
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0B0F0C)
          : const Color(0xFFF4F0E7),
      canvasColor: scheme.surface,
      splashColor: scheme.primary.withValues(alpha: 0.08),
      highlightColor: scheme.primary.withValues(alpha: 0.04),
    );

    final textTheme = _textTheme(base.textTheme);
    final cardColor = isDark
        ? scheme.surfaceContainerLow
        : scheme.surfaceContainerLowest;
    final cardBorder = scheme.outlineVariant.withValues(
      alpha: isDark ? 0.42 : 0.62,
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme.apply(
        bodyColor: scheme.onPrimaryContainer,
        displayColor: scheme.onPrimaryContainer,
      ),
      extensions: <ThemeExtension<dynamic>>[
        isDark ? MacroColors.dark : MacroColors.light,
      ],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: scheme.shadow.withValues(alpha: 0.08),
        centerTitle: false,
        toolbarHeight: 62,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        actionsIconTheme: IconThemeData(color: scheme.onSurface, size: 22),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        color: cardColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: cardBorder),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.65)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          padding: const EdgeInsets.all(10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primaryContainer,
        secondarySelectedColor: scheme.primaryContainer,
        disabledColor: scheme.surfaceContainerHighest,
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.62)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withValues(alpha: 0.14),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLow,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        floatingLabelStyle: textTheme.labelMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.error, width: 1.6),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: Colors.black.withValues(alpha: 0.42),
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.32),
        dragHandleSize: const Size(38, 4),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: cardBorder),
        ),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: scheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
          height: 1.55,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
        iconColor: scheme.primary,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        actionTextColor: scheme.inversePrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
          height: 1.4,
        ),
        elevation: 2,
        insetPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.12),
        circularTrackColor: scheme.primary.withValues(alpha: 0.12),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(9),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
    );
  }

  static TextTheme _textTheme(TextTheme base) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
        height: 1.06,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        height: 1.12,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.14,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.2,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        height: 1.3,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.35,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        height: 1.4,
      ),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.6),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.55),
      bodySmall: base.bodySmall?.copyWith(height: 1.5),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelSmall: base.labelSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
    );
  }

  /// Dark, teal-tinted stage gradient used by the scanner hero. Kept here so
  /// every surface that needs the photographic stage stays visually related to
  /// the active color scheme.
  static List<Color> stageGradient(ColorScheme scheme) {
    return <Color>[
      Color.lerp(scheme.primary, _stageInk, 0.82)!,
      Color.lerp(scheme.primary, _stageInk, 0.70)!,
      Color.lerp(scheme.primary, _stageInk, 0.58)!,
    ];
  }

  /// Accent used on the scanner stage for the scan line and busy indicators.
  static Color stageAccent(ColorScheme scheme) {
    return Color.lerp(scheme.primary, Colors.white, 0.62)!;
  }
}
