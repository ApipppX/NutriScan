import 'package:flutter/material.dart';

import '../../../../core/localization/food_label_localizer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/food_candidate.dart';
import '../../domain/entities/nutrition_facts.dart';
import '../../domain/entities/scan_result.dart';
import 'ai_confidence_panel.dart';
import 'macro_donut_chart.dart';
import 'nutrition_detail_sheet.dart';
import 'portion_selector.dart';

/// Comprehensive, per-serving result view for a completed scan.
///
/// This widget is stateless: portion selection, candidate selection, retake,
/// and diary persistence are owned by the scan controller and the diary
/// controller respectively.
final class ScanResultCard extends StatelessWidget {
  const ScanResultCard({
    super.key,
    required this.result,
    required this.portionGrams,
    required this.onSelectCandidate,
    required this.onPortionChanged,
    required this.onRetake,
    required this.onScanAgain,
  });

  final ScanResult result;
  final int portionGrams;
  final ValueChanged<String> onSelectCandidate;
  final ValueChanged<int> onPortionChanged;
  final VoidCallback onRetake;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final macros = theme.extension<MacroColors>()!;
    final selected = result.selected;
    final food = selected.food;
    final facts = selected.nutritionForPortion(portionGrams);
    final unit = portionUnitForCategory(food.category);
    final displayName = FoodLabelLocalizer.resolve(
      food.label,
      displayName: food.displayName,
    );
    final isTopPrediction = result.selectedIndex == 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: 58,
                  height: 58,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    selected.emoji,
                    style: const TextStyle(fontSize: 29),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        isTopPrediction
                            ? 'Prediksi utama'
                            : 'Alternatif pilihan',
                        style: textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: <Widget>[
                          _MetaChip(
                            icon: Icons.restaurant_rounded,
                            label: categoryLabel(food.category),
                          ),
                          _MetaChip(
                            icon: Icons.scale_rounded,
                            label: formatPortionInUnit(portionGrams, unit),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AiConfidencePanel(
              confidence: selected.confidence,
              onRetake: onRetake,
            ),
            const SizedBox(height: 18),
            PortionSelector(
              food: food,
              portionGrams: portionGrams,
              onChanged: onPortionChanged,
            ),
            const SizedBox(height: 22),
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Ringkasan gizi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Per ${formatPortionInUnit(portionGrams, unit)}',
                  maxLines: 1,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final chart = MacroDonutChart(facts: facts);
                final legend = Column(
                  children: <Widget>[
                    MacroLegendTile(
                      label: 'Protein',
                      grams: facts.proteinG,
                      energyShare: facts.energyShare(MacroNutrient.protein),
                      color: macros.protein,
                      icon: Icons.fitness_center_rounded,
                    ),
                    const SizedBox(height: 12),
                    MacroLegendTile(
                      label: 'Karbohidrat',
                      grams: facts.carbohydrateG,
                      energyShare: facts.energyShare(
                        MacroNutrient.carbohydrates,
                      ),
                      color: macros.carbohydrates,
                      icon: Icons.rice_bowl_rounded,
                    ),
                    const SizedBox(height: 12),
                    MacroLegendTile(
                      label: 'Lemak',
                      grams: facts.fatG,
                      energyShare: facts.energyShare(MacroNutrient.fat),
                      color: macros.fat,
                      icon: Icons.water_drop_rounded,
                    ),
                  ],
                );

                if (constraints.maxWidth >= 430) {
                  return Row(
                    children: <Widget>[
                      chart,
                      const SizedBox(width: 22),
                      Expanded(child: legend),
                    ],
                  );
                }
                return Column(
                  children: <Widget>[chart, const SizedBox(height: 18), legend],
                );
              },
            ),
            const SizedBox(height: 18),
            _NutritionGrid(
              facts: facts,
              portionGrams: portionGrams,
              unit: unit,
            ),
            if (result.hasAlternatives) ...<Widget>[
              const SizedBox(height: 20),
              Text(
                'Bukan ini?',
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (var index = 0; index < result.candidates.length; index++)
                    _AlternativeChip(
                      candidate: result.candidates[index],
                      selected: index == result.selectedIndex,
                      onSelected: () =>
                          onSelectCandidate(result.candidates[index].label),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final detailsButton = OutlinedButton.icon(
                  onPressed: () => showNutritionDetailSheet(
                    context,
                    selected,
                    portionGrams: portionGrams,
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 19),
                  label: const Text('Rincian lengkap'),
                );
                final scanAgainButton = TextButton.icon(
                  onPressed: onScanAgain,
                  icon: const Icon(Icons.refresh_rounded, size: 19),
                  label: const Text('Pindai lagi'),
                );

                if (constraints.maxWidth < 360) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      detailsButton,
                      const SizedBox(height: 4),
                      scanAgainButton,
                    ],
                  );
                }
                return Row(
                  children: <Widget>[
                    Expanded(child: detailsButton),
                    const SizedBox(width: 8),
                    Expanded(child: scanAgainButton),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

final class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

final class _NutritionGrid extends StatelessWidget {
  const _NutritionGrid({
    required this.facts,
    required this.portionGrams,
    required this.unit,
  });

  final NutritionFacts facts;
  final int portionGrams;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final macros = Theme.of(context).extension<MacroColors>()!;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _NutritionFactTile(
                icon: Icons.local_fire_department_rounded,
                label: 'Kalori',
                value: formatKcal(facts.caloriesKcal),
                color: macros.calories,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NutritionFactTile(
                icon: Icons.fitness_center_rounded,
                label: 'Protein',
                value: formatGrams(facts.proteinG),
                color: macros.protein,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _NutritionFactTile(
                icon: Icons.rice_bowl_rounded,
                label: 'Karbohidrat',
                value: formatGrams(facts.carbohydrateG),
                color: macros.carbohydrates,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NutritionFactTile(
                icon: Icons.water_drop_rounded,
                label: 'Lemak',
                value: formatGrams(facts.fatG),
                color: macros.fat,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: _NutritionFactTile(
                icon: Icons.grass_rounded,
                label: 'Serat',
                value: formatGrams(facts.fiberG),
                color: scheme.tertiary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NutritionFactTile(
                icon: Icons.grain_rounded,
                label: 'Natrium',
                value: '${facts.sodiumMg.round()} mg',
                color: scheme.secondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Nilai gizi dihitung otomatis untuk porsi '
          '${formatPortionInUnit(portionGrams, unit)}. '
          'Estimasi dapat berbeda tergantung resep.',
          textAlign: TextAlign.left,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

final class _NutritionFactTile extends StatelessWidget {
  const _NutritionFactTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

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
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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

final class _AlternativeChip extends StatelessWidget {
  const _AlternativeChip({
    required this.candidate,
    required this.selected,
    required this.onSelected,
  });

  final FoodCandidate candidate;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final displayName = FoodLabelLocalizer.resolve(
      candidate.label,
      displayName: candidate.displayName,
    );
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (value) {
        if (value) onSelected();
      },
      label: Text('${candidate.emoji}  $displayName'),
      tooltip: '${formatPercent(candidate.confidence)} keyakinan',
    );
  }
}
