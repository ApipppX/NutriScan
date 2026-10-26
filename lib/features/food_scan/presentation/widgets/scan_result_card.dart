import 'package:flutter/material.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/food_candidate.dart';
import '../../domain/entities/nutrition_facts.dart';
import '../../domain/entities/scan_result.dart';
import 'macro_energy_bar.dart';
import 'nutrition_detail_sheet.dart';

/// Prediction + nutrition summary for a completed scan.
final class ScanResultCard extends StatelessWidget {
  const ScanResultCard({
    super.key,
    required this.result,
    required this.onSelectCandidate,
    required this.onScanAgain,
  });

  final ScanResult result;
  final ValueChanged<String> onSelectCandidate;
  final VoidCallback onScanAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final macros = theme.extension<MacroColors>()!;
    final selected = result.selected;
    final facts = selected.defaultPortionNutrition;
    final unit = portionUnitForCategory(selected.food.category);
    final isLowConfidence =
        selected.confidence < AppConfig.confidenceWarningThreshold;
    final isTopPrediction = result.selectedIndex == 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    selected.emoji,
                    style: const TextStyle(fontSize: 28),
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
                        selected.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _ConfidenceBadge(
                  confidence: selected.confidence,
                  isLow: isLowConfidence,
                ),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '${facts.caloriesKcal.round()}',
                  style: textTheme.displaySmall?.copyWith(
                    color: macros.calories,
                    fontSize: 42,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5, left: 4),
                  child: Text(
                    'kkal',
                    style: textTheme.titleSmall?.copyWith(
                      color: macros.calories.withValues(alpha: 0.76),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                _PortionPill(
                  label: formatPortionInUnit(
                    selected.food.defaultPortionGrams,
                    unit,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Perkiraan energi untuk porsi ini',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            MacroEnergyBar(facts: facts),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: MacroStatTile(
                    label: 'Protein',
                    grams: facts.proteinG,
                    energyShare: facts.energyShare(MacroNutrient.protein),
                    color: macros.protein,
                    containerColor: macros.proteinContainer,
                    icon: Icons.fitness_center_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MacroStatTile(
                    label: 'Karbo',
                    grams: facts.carbohydrateG,
                    energyShare: facts.energyShare(MacroNutrient.carbohydrates),
                    color: macros.carbohydrates,
                    containerColor: macros.carbohydratesContainer,
                    icon: Icons.rice_bowl_rounded,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: MacroStatTile(
                    label: 'Lemak',
                    grams: facts.fatG,
                    energyShare: facts.energyShare(MacroNutrient.fat),
                    color: macros.fat,
                    containerColor: macros.fatContainer,
                    icon: Icons.water_drop_rounded,
                  ),
                ),
              ],
            ),
            if (isLowConfidence) ...<Widget>[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: scheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Keyakinan model masih rendah. Coba foto dari sudut lain '
                        'atau pilih alternatif di bawah.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onTertiaryContainer,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => showNutritionDetailSheet(context, selected),
              icon: const Icon(Icons.tune_rounded, size: 20),
              label: const Text('Atur porsi & rincian'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onScanAgain,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Pindai makanan lain'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ConfidenceBadge extends StatelessWidget {
  const _ConfidenceBadge({required this.confidence, required this.isLow});

  final double confidence;
  final bool isLow;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = isLow
        ? scheme.tertiaryContainer
        : scheme.primaryContainer;
    final foreground = isLow
        ? scheme.onTertiaryContainer
        : scheme.onPrimaryContainer;
    return Tooltip(
      message: 'Tingkat keyakinan model terhadap prediksi ini',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              isLow ? Icons.help_outline_rounded : Icons.verified_rounded,
              size: 14,
              color: foreground,
            ),
            const SizedBox(width: 4),
            Text(
              formatPercent(confidence),
              style: Theme.of(context).textTheme.labelMedium
                  ?.copyWith(color: foreground, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PortionPill extends StatelessWidget {
  const _PortionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.scale_rounded, size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
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
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (value) {
        if (value) onSelected();
      },
      label: Text('${candidate.emoji}  ${candidate.displayName}'),
      tooltip: '${formatPercent(candidate.confidence)} keyakinan',
    );
  }
}
