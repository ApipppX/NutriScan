import 'package:flutter/material.dart';

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
    calories: Color(0xFFB75B13),
    caloriesContainer: Color(0xFFFCE7D3),
    protein: Color(0xFF176B5B),
    proteinContainer: Color(0xFFD6EEE8),
    carbohydrates: Color(0xFF8A6200),
    carbohydratesContainer: Color(0xFFF7EAC6),
    fat: Color(0xFFA23E35),
    fatContainer: Color(0xFFF7DED9),
  );

  static const MacroColors dark = MacroColors(
    calories: Color(0xFFFFB870),
    caloriesContainer: Color(0xFF4B2B10),
    protein: Color(0xFF75DCC7),
    proteinContainer: Color(0xFF10342D),
    carbohydrates: Color(0xFFF0C65C),
    carbohydratesContainer: Color(0xFF3B2E0B),
    fat: Color(0xFFFFA79C),
    fatContainer: Color(0xFF421E1A),
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

abstract final class AppTheme {
  static const Color _seed = Color(0xFF356B3B);

  static ThemeData get light => _build(Brightness.light);
  static ThemeData get dark => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final scheme =
        ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: brightness,
          dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
        ).copyWith(
          surface: isDark ? const Color(0xFF121610) : const Color(0xFFFBF9F3),
          surfaceContainerLowest: isDark
              ? const Color(0xFF0C100B)
              : const Color(0xFFFFFFFF),
        );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark
          ? const Color(0xFF0C100B)
          : const Color(0xFFF6F3EA),
    );
    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.4,
        height: 1.06,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.12,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.2,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.55),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.5),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      extensions: <ThemeExtension<dynamic>>[
        isDark ? MacroColors.dark : MacroColors.light,
      ],
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.7)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        labelStyle: textTheme.labelMedium,
        selectedColor: scheme.primaryContainer,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: scheme.primary,
        inactiveTrackColor: scheme.primary.withValues(alpha: 0.16),
        thumbColor: scheme.primary,
        overlayColor: scheme.primary.withValues(alpha: 0.12),
        trackHeight: 5,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: scheme.onSurfaceVariant.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.primary.withValues(alpha: 0.14),
        circularTrackColor: scheme.primary.withValues(alpha: 0.14),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.55),
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: scheme.inverseSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
      ),
    );
  }
}
