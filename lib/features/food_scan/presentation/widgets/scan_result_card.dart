import 'package:flutter/material.dart';

import '../../../../core/localization/food_label_localizer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/food_candidate.dart';
import '../../domain/entities/food_nutrition.dart';
import '../../domain/entities/nutrition_facts.dart';
import '../../domain/entities/scan_result.dart';
import 'ai_confidence_panel.dart';
import 'macro_donut_chart.dart';
import 'nutrition_detail_sheet.dart';
import 'nutrition_summary_table.dart';
import 'portion_selector.dart';
import 'supported_foods_sheet.dart';

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
    required this.supportedFoods,
    required this.onSelectCandidate,
    required this.onPortionChanged,
    required this.onRetake,
    required this.onScanAgain,
  });

  final ScanResult result;
  final int portionGrams;

  /// Every food the closed-set model can recognize.
  final List<FoodNutrition> supportedFoods;
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
              margin: result.hasAlternatives ? result.confidenceMargin : null,
              isManualSelection: result.isManualSelection,
              onRetake: onRetake,
              onShowSupportedFoods: () => showSupportedFoodsSheet(
                context,
                foods: supportedFoods,
                selectedLabel: selected.label,
              ),
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
            NutritionSummaryTable(
              portionFacts: facts,
              per100g: food.per100g,
              unit: unit,
            ),
            const SizedBox(height: 20),
            Text(
              'Bukan ini?',
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (result.hasAlternatives) ...<Widget>[
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
            if (supportedFoods.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => showSupportedFoodsSheet(
                    context,
                    foods: supportedFoods,
                    selectedLabel: selected.label,
                  ),
                  icon: const Icon(Icons.list_alt_rounded, size: 18),
                  label: Text(
                    'Lihat ${supportedFoods.length} makanan yang didukung',
                  ),
                ),
              ),
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
