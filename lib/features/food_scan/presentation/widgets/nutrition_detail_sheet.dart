import 'package:flutter/material.dart';

import '../../../../core/localization/food_label_localizer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/food_candidate.dart';
import 'macro_energy_bar.dart';
import 'nutrition_estimate_badge.dart';
import 'nutrition_summary_table.dart';

/// Opens the read-only nutrition breakdown for the current portion.
///
/// Portion adjustments happen on the result card; this sheet is the detailed
/// reference view with the same per-portion/per-100 table used in the card.
Future<void> showNutritionDetailSheet(
  BuildContext context,
  FoodCandidate candidate, {
  required int portionGrams,
  bool provisional = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => _NutritionDetailSheet(
      candidate: candidate,
      portionGrams: portionGrams,
      provisional: provisional,
    ),
  );
}

final class _NutritionDetailSheet extends StatelessWidget {
  const _NutritionDetailSheet({
    required this.candidate,
    required this.portionGrams,
    this.provisional = false,
  });

  final FoodCandidate candidate;
  final int portionGrams;

  /// Shows the temporary-estimate state while the food class is uncertain.
  final bool provisional;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final macros = theme.extension<MacroColors>()!;
    final food = candidate.food;
    final facts = candidate.nutritionForPortion(portionGrams);
    final unit = portionUnitForCategory(food.category);
    final displayName = FoodLabelLocalizer.resolve(
      food.label,
      displayName: food.displayName,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 26),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Text(
                        food.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: NutritionEstimateBadge(
                              provisional: provisional,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${categoryLabel(food.category)} · '
                            '${formatPercent(candidate.confidence)} keyakinan',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        macros.caloriesContainer,
                        macros.caloriesContainer.withValues(alpha: 0.45),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: macros.calories.withValues(alpha: 0.13),
                        ),
                        child: Icon(
                          Icons.local_fire_department_rounded,
                          color: macros.calories,
                          size: 23,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              'Total energi',
                              style: textTheme.labelSmall?.copyWith(
                                color: macros.calories.withValues(alpha: 0.8),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              formatKcal(facts.caloriesKcal),
                              style: textTheme.headlineSmall?.copyWith(
                                color: macros.calories,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.66),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          formatPortionInUnit(portionGrams, unit),
                          style: textTheme.labelMedium?.copyWith(
                            color: macros.calories,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Text('Distribusi energi', style: textTheme.titleMedium),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Protein · Karbo · Lemak',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                MacroEnergyBar(facts: facts),
                const SizedBox(height: 20),
                Text('Rincian zat gizi', style: textTheme.titleMedium),
                const SizedBox(height: 10),
                NutritionSummaryTable(
                  portionFacts: facts,
                  per100g: food.per100g,
                  unit: unit,
                  provisional: provisional,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Tutup'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
