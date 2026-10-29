import 'package:flutter/material.dart';

import '../../../../core/localization/food_label_localizer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/food_candidate.dart';
import '../../domain/entities/nutrition_facts.dart';
import 'macro_energy_bar.dart';

/// Opens the read-only nutrition breakdown for the current portion.
///
/// Portion adjustments happen on the result card; this sheet is the detailed
/// reference view (macros, fiber, sodium, and per-100 g values).
Future<void> showNutritionDetailSheet(
  BuildContext context,
  FoodCandidate candidate, {
  required int portionGrams,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) =>
        _NutritionDetailSheet(candidate: candidate, portionGrams: portionGrams),
  );
}

final class _NutritionDetailSheet extends StatelessWidget {
  const _NutritionDetailSheet({
    required this.candidate,
    required this.portionGrams,
  });

  final FoodCandidate candidate;
  final int portionGrams;

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
                          const SizedBox(height: 2),
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
                    Text('Makronutrien', style: textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      formatPortionInUnit(portionGrams, unit),
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                MacroEnergyBar(facts: facts),
                const SizedBox(height: 14),
                _MacroDetailRow(
                  label: 'Protein',
                  grams: facts.proteinG,
                  share: facts.energyShare(MacroNutrient.protein),
                  color: macros.protein,
                  containerColor: macros.proteinContainer,
                  icon: Icons.fitness_center_rounded,
                ),
                const SizedBox(height: 8),
                _MacroDetailRow(
                  label: 'Karbohidrat',
                  grams: facts.carbohydrateG,
                  share: facts.energyShare(MacroNutrient.carbohydrates),
                  color: macros.carbohydrates,
                  containerColor: macros.carbohydratesContainer,
                  icon: Icons.rice_bowl_rounded,
                ),
                const SizedBox(height: 8),
                _MacroDetailRow(
                  label: 'Lemak',
                  grams: facts.fatG,
                  share: facts.energyShare(MacroNutrient.fat),
                  color: macros.fat,
                  containerColor: macros.fatContainer,
                  icon: Icons.water_drop_rounded,
                ),
                const SizedBox(height: 18),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _ExtraFactTile(
                        icon: Icons.grass_rounded,
                        label: 'Serat',
                        value: formatGrams(facts.fiberG),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ExtraFactTile(
                        icon: Icons.grain_rounded,
                        label: 'Natrium',
                        value: '${facts.sodiumMg.round()} mg',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.6,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Per 100 $unit: ${formatKcal(food.per100g.caloriesKcal)} · '
                    'P ${formatGrams(food.per100g.proteinG)} · '
                    'K ${formatGrams(food.per100g.carbohydrateG)} · '
                    'L ${formatGrams(food.per100g.fatG)} · '
                    'Serat ${formatGrams(food.per100g.fiberG)} · '
                    'Na ${food.per100g.sodiumMg.round()} mg',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Nilai gizi adalah estimasi dan dapat berbeda tergantung resep, '
                        'bahan, serta ukuran porsi. Bukan pengganti saran medis.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
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

final class _MacroDetailRow extends StatelessWidget {
  const _MacroDetailRow({
    required this.label,
    required this.grams,
    required this.share,
    required this.color,
    required this.containerColor,
    required this.icon,
  });

  final String label;
  final double grams;
  final double share;
  final Color color;
  final Color containerColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: containerColor.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        label,
                        style: textTheme.labelLarge?.copyWith(color: color),
                      ),
                    ),
                    Text(
                      formatGrams(grams),
                      style: textTheme.labelLarge?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: share.clamp(0.0, 1.0),
                    minHeight: 5,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 42,
            child: Text(
              formatPercent(share, decimals: 0),
              textAlign: TextAlign.end,
              style: textTheme.labelSmall?.copyWith(
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _ExtraFactTile extends StatelessWidget {
  const _ExtraFactTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
