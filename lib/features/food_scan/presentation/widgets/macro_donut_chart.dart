import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/nutrition_facts.dart';

/// Animated donut chart showing the energy split between protein, carbs, fat.
final class MacroDonutChart extends StatelessWidget {
  const MacroDonutChart({
    super.key,
    required this.facts,
    this.size = 150,
    this.strokeWidth = 18,
  });

  final NutritionFacts facts;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final macros = Theme.of(context).extension<MacroColors>()!;
    final textTheme = Theme.of(context).textTheme;
    final shares = <double>[
      facts.energyShare(MacroNutrient.protein),
      facts.energyShare(MacroNutrient.carbohydrates),
      facts.energyShare(MacroNutrient.fat),
    ];
    final colors = <Color>[macros.protein, macros.carbohydrates, macros.fat];

    return Semantics(
      label:
          'Komposisi energi: protein ${formatPercent(shares[0], decimals: 0)}, '
          'karbohidrat ${formatPercent(shares[1], decimals: 0)}, '
          'lemak ${formatPercent(shares[2], decimals: 0)}. '
          'Total ${formatKcal(facts.caloriesKcal)}.',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 720),
        curve: Curves.easeOutCubic,
        builder: (BuildContext context, double progress, Widget? child) {
          return SizedBox(
            width: size,
            height: size,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                CustomPaint(
                  painter: _MacroDonutPainter(
                    shares: shares,
                    colors: colors,
                    trackColor: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    strokeWidth: strokeWidth,
                    progress: progress,
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        '${facts.caloriesKcal.round()}',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      Text(
                        'kkal',
                        style: textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

final class _MacroDonutPainter extends CustomPainter {
  const _MacroDonutPainter({
    required this.shares,
    required this.colors,
    required this.trackColor,
    required this.strokeWidth,
    required this.progress,
  });

  final List<double> shares;
  final List<Color> colors;
  final Color trackColor;
  final double strokeWidth;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final total = shares.fold<double>(0, (sum, share) => sum + share);
    if (total <= 0) return;

    const gap = 0.045;
    var startAngle = -math.pi / 2;
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    for (var index = 0; index < shares.length; index++) {
      final share = shares[index] / total;
      if (share <= 0) continue;
      final sweep = share * math.pi * 2 * progress;
      if (sweep <= gap) {
        startAngle += share * math.pi * 2;
        continue;
      }
      arcPaint.color = colors[index];
      canvas.drawArc(rect, startAngle + gap / 2, sweep - gap, false, arcPaint);
      startAngle += share * math.pi * 2;
    }
  }

  @override
  bool shouldRepaint(covariant _MacroDonutPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.shares != shares ||
      oldDelegate.colors != colors ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackColor != trackColor;
}

/// A compact legend row with a linear progress indicator.
final class MacroLegendTile extends StatelessWidget {
  const MacroLegendTile({
    super.key,
    required this.label,
    required this.grams,
    required this.energyShare,
    required this.color,
    required this.icon,
  });

  final String label;
  final double grams;
  final double energyShare;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label:
          '$label ${formatGrams(grams)}, '
          '${formatPercent(energyShare, decimals: 0)} dari energi.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                formatGrams(grams),
                style: textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 36,
                child: Text(
                  formatPercent(energyShare, decimals: 0),
                  textAlign: TextAlign.end,
                  style: textTheme.labelSmall?.copyWith(
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: energyShare.clamp(0.0, 1.0),
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }
}
