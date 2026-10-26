import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/nutrition_facts.dart';

/// Horizontal stacked bar showing the share of energy from protein, carbs, fat.
final class MacroEnergyBar extends StatelessWidget {
  const MacroEnergyBar({super.key, required this.facts, this.height = 10});

  final NutritionFacts facts;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<MacroColors>()!;
    final total = facts.macroCaloriesKcal;
    final shares = <(MacroNutrient, double, Color)>[
      (MacroNutrient.protein, facts.proteinCaloriesKcal, colors.protein),
      (
        MacroNutrient.carbohydrates,
        facts.carbohydrateCaloriesKcal,
        colors.carbohydrates,
      ),
      (MacroNutrient.fat, facts.fatCaloriesKcal, colors.fat),
    ];
    final segments = <Widget>[
      for (final (_, calories, color) in shares)
        if (calories > 0 && total > 0)
          Expanded(
            flex: (calories / total * 1000).round().clamp(1, 1000),
            child: ColoredBox(color: color),
          ),
    ];

    return Semantics(
      label:
          'Komposisi energi: '
          'protein ${formatPercent(facts.energyShare(MacroNutrient.protein), decimals: 0)}, '
          'karbohidrat ${formatPercent(facts.energyShare(MacroNutrient.carbohydrates), decimals: 0)}, '
          'lemak ${formatPercent(facts.energyShare(MacroNutrient.fat), decimals: 0)}.',
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(height / 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: segments.isEmpty
            ? const SizedBox.expand()
            : Row(children: segments),
      ),
    );
  }
}

/// Compact macro tile used on the result card.
final class MacroStatTile extends StatelessWidget {
  const MacroStatTile({
    super.key,
    required this.label,
    required this.grams,
    required this.energyShare,
    required this.color,
    required this.containerColor,
    required this.icon,
  });

  final String label;
  final double grams;
  final double energyShare;
  final Color color;
  final Color containerColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: containerColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              formatGrams(grams),
              style: textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${formatPercent(energyShare, decimals: 0)} energi',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: color.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}
