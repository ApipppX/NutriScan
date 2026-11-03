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
import 'nutrition_estimate_badge.dart';
import 'nutrition_summary_table.dart';
import 'portion_selector.dart';
import 'supported_foods_sheet.dart';

/// Comprehensive, per-serving result view for a completed scan.
///
/// This widget animates its entrance: fade-in the entire card, then slide
/// up the nutrition section with a slight delay for a polished reveal.
final class ScanResultCard extends StatefulWidget {
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
  State<ScanResultCard> createState() => _ScanResultCardState();
}

class _ScanResultCardState extends State<ScanResultCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final macros = theme.extension<MacroColors>()!;
    final selected = widget.result.selected;
    final food = selected.food;
    final facts = selected.nutritionForPortion(widget.portionGrams);
    final unit = portionUnitForCategory(food.category);
    final displayName = FoodLabelLocalizer.resolve(
      food.label,
      displayName: food.displayName,
    );
    final isTopPrediction = widget.result.selectedIndex == 0;
    final provisional = widget.result.selectedNeedsReview;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                // Result identity header.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: <Color>[
                        scheme.primaryContainer.withValues(alpha: 0.58),
                        scheme.surfaceContainerLow.withValues(alpha: 0.82),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: scheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.12),
                          ),
                        ),
                        child: Text(
                          selected.emoji,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              isTopPrediction
                                  ? 'Prediksi utama'
                                  : 'Alternatif pilihan',
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleLarge,
                            ),
                            const SizedBox(height: 7),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: <Widget>[
                                NutritionEstimateBadge(provisional: provisional),
                                _MetaChip(
                                  icon: Icons.restaurant_rounded,
                                  label: categoryLabel(food.category),
                                ),
                                _MetaChip(
                                  icon: Icons.scale_rounded,
                                  label: formatPortionInUnit(
                                    widget.portionGrams,
                                    unit,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                AiConfidencePanel(
                  confidence: selected.confidence,
                  margin: widget.result.hasAlternatives
                      ? widget.result.confidenceMargin
                      : null,
                  topThreeMass: widget.result.topThreeMass,
                  supportedCount: widget.supportedFoods.isEmpty
                      ? null
                      : widget.supportedFoods.length,
                  isManualSelection: widget.result.isManualSelection,
                  onRetake: widget.onRetake,
                  onShowSupportedFoods: () => showSupportedFoodsSheet(
                    context,
                    foods: widget.supportedFoods,
                    selectedLabel: selected.label,
                  ),
                ),
                const SizedBox(height: 18),
                PortionSelector(
                  food: food,
                  portionGrams: widget.portionGrams,
                  onChanged: widget.onPortionChanged,
                ),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.donut_large_rounded,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 7),
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
                      'Per ${formatPortionInUnit(widget.portionGrams, unit)}',
                      maxLines: 1,
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _AnimatedNutritionSection(
                  animation: _controller,
                  facts: facts,
                  macros: macros,
                ),
                const SizedBox(height: 18),
                NutritionSummaryTable(
                  portionFacts: facts,
                  per100g: food.per100g,
                  unit: unit,
                  provisional: provisional,
                ),
                const SizedBox(height: 20),
                // Alternatives panel.
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 13, 14, 6),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Icon(
                            Icons.swap_horiz_rounded,
                            size: 17,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Bukan ini?',
                              style: textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (widget.result.hasAlternatives) ...<Widget>[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            for (
                              var index = 0;
                              index < widget.result.candidates.length;
                              index++
                            )
                              _AlternativeChip(
                                candidate: widget.result.candidates[index],
                                selected: index == widget.result.selectedIndex,
                                onSelected: () => widget.onSelectCandidate(
                                  widget.result.candidates[index].label,
                                ),
                              ),
                          ],
                        ),
                      ],
                      if (widget.supportedFoods.isNotEmpty)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => showSupportedFoodsSheet(
                              context,
                              foods: widget.supportedFoods,
                              selectedLabel: selected.label,
                            ),
                            icon: const Icon(Icons.list_alt_rounded, size: 18),
                            label: Text(
                              'Lihat ${widget.supportedFoods.length} makanan yang didukung',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    final detailsButton = OutlinedButton.icon(
                      onPressed: () => showNutritionDetailSheet(
                        context,
                        selected,
                        portionGrams: widget.portionGrams,
                        provisional: provisional,
                      ),
                      icon: const Icon(Icons.receipt_long_rounded, size: 19),
                      label: const Text('Rincian lengkap'),
                    );
                    final scanAgainButton = TextButton.icon(
                      onPressed: widget.onScanAgain,
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
        ),
      ),
    );
  }
}

/// Animated donut + legend with staggered entrance.
final class _AnimatedNutritionSection extends StatelessWidget {
  const _AnimatedNutritionSection({
    required this.animation,
    required this.facts,
    required this.macros,
  });

  final Animation<double> animation;
  final NutritionFacts facts;
  final MacroColors macros;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final chart = MacroDonutChart(facts: facts);
        final legend = Column(
          children: <Widget>[
            _AnimatedMacroTile(
              animation: animation,
              delay: 0.25,
              label: 'Protein',
              grams: facts.proteinG,
              energyShare: facts.energyShare(MacroNutrient.protein),
              color: macros.protein,
              icon: Icons.fitness_center_rounded,
            ),
            const SizedBox(height: 12),
            _AnimatedMacroTile(
              animation: animation,
              delay: 0.35,
              label: 'Karbohidrat',
              grams: facts.carbohydrateG,
              energyShare: facts.energyShare(MacroNutrient.carbohydrates),
              color: macros.carbohydrates,
              icon: Icons.rice_bowl_rounded,
            ),
            const SizedBox(height: 12),
            _AnimatedMacroTile(
              animation: animation,
              delay: 0.45,
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
    );
  }
}

/// Macro legend tile with fade + slide entrance.
final class _AnimatedMacroTile extends StatelessWidget {
  const _AnimatedMacroTile({
    required this.animation,
    required this.delay,
    required this.label,
    required this.grams,
    required this.energyShare,
    required this.color,
    required this.icon,
  });

  final Animation<double> animation;
  final double delay;
  final String label;
  final double grams;
  final double energyShare;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(
      parent: animation,
      curve: Interval(delay, (delay + 0.35).clamp(0.0, 1.0), curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0.15, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: animation,
        curve: Interval(delay, (delay + 0.35).clamp(0.0, 1.0), curve: Curves.easeOutCubic),
      ),
    );

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: MacroLegendTile(
          label: label,
          grams: grams,
          energyShare: energyShare,
          color: color,
          icon: icon,
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
        color: scheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.45),
        ),
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
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: FilterChip(
        selected: selected,
        onSelected: (_) => onSelected(),
        avatar: Text(candidate.emoji, style: const TextStyle(fontSize: 14)),
        label: Text(
          FoodLabelLocalizer.resolve(
            candidate.label,
            displayName: candidate.food.displayName,
          ),
        ),
        labelStyle: textTheme.labelMedium?.copyWith(
          color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
        selectedColor: scheme.primaryContainer,
        checkmarkColor: scheme.onPrimaryContainer,
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected
                ? scheme.primary.withValues(alpha: 0.24)
                : scheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
