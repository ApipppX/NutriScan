import 'package:flutter/material.dart';

/// Compact brand mark used on the splash screen and top bar.
final class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final gradientEnd = Color.lerp(scheme.primary, scheme.tertiary, 0.42)!;
    return Semantics(
      label: 'Logo NutriScan',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.31),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [scheme.primary, gradientEnd],
          ),
          border: Border.all(
            color: scheme.onPrimary.withValues(alpha: 0.18),
            width: 1,
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: scheme.primary.withValues(alpha: 0.24),
              blurRadius: size * 0.38,
              offset: Offset(0, size * 0.14),
            ),
          ],
        ),
        child: Icon(
          Icons.restaurant_menu_rounded,
          size: size * 0.52,
          color: scheme.onPrimary,
        ),
      ),
    );
  }
}
