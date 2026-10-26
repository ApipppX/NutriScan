import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/food_candidate.dart';
import '../../domain/entities/nutrition_facts.dart';
import 'macro_energy_bar.dart';

/// Opens the portion-adjustment and nutrition detail bottom sheet.
Future<void> showNutritionDetailSheet(
  BuildContext context,
  FoodCandidate candidate,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) =>
        _NutritionDetailSheet(candidate: candidate),
  );
}

final class _NutritionDetailSheet extends StatefulWidget {
  const _NutritionDetailSheet({required this.candidate});

  final FoodCandidate candidate;

  @override
  State<_NutritionDetailSheet> createState() => _NutritionDetailSheetState();
}

final class _NutritionDetailSheetState extends State<_NutritionDetailSheet> {
  late final String _unit = portionUnitForCategory(
    widget.candidate.food.category,
  );
  late final int _minPortion = widget.candidate.food.defaultPortionGrams <= 100
      ? 25
      : 50;
  late final int _maxPortion = _calculateMaxPortion(
    widget.candidate.food.defaultPortionGrams,
  );
  late int _portion = widget.candidate.food.defaultPortionGrams.clamp(
    _minPortion,
    _maxPortion,
  );

  static int _calculateMaxPortion(int defaultPortion) {
    final target = (defaultPortion * 2.5 / 10).ceil() * 10;
    return target < 500 ? 500 : target;
  }

  NutritionFacts get _facts => widget.candidate.nutritionForPortion(_portion);

  void _setPortion(int value) {
    final next = value.clamp(_minPortion, _maxPortion);
    if (next == _portion) return;
    setState(() => _portion = next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final macros = theme.extension<MacroColors>()!;
    final food = widget.candidate.food;
    final facts = _facts;

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
                            food.displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_categoryLabel(food.category)} · '
                            '${formatPercent(widget.candidate.confidence)} keyakinan',
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
                          formatPortionInUnit(_portion, _unit),
                          style: textTheme.labelMedium?.copyWith(
                            color: macros.calories,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('Atur porsi', style: textTheme.titleMedium),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Column(
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          IconButton.filledTonal(
                            onPressed: _portion > _minPortion
                                ? () => _setPortion(_portion - 10)
                                : null,
                            tooltip: 'Kurangi porsi',
                            icon: const Icon(Icons.remove_rounded),
                          ),
                          Expanded(
                            child: Column(
                              children: <Widget>[
                                Text(
                                  formatPortionInUnit(_portion, _unit),
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Geser untuk menyesuaikan',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton.filledTonal(
                            onPressed: _portion < _maxPortion
                                ? () => _setPortion(_portion + 10)
                                : null,
                            tooltip: 'Tambah porsi',
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                      Slider(
                        value: _portion.toDouble(),
                        min: _minPortion.toDouble(),
                        max: _maxPortion.toDouble(),
                        divisions: (_maxPortion - _minPortion) ~/ 10,
                        label: formatPortionInUnit(_portion, _unit),
                        onChanged: (value) =>
                            _setPortion((value / 10).round() * 10),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            formatPortionInUnit(_minPortion, _unit),
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            'Porsi awal ${food.defaultPortionGrams} $_unit',
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            formatPortionInUnit(_maxPortion, _unit),
                            style: textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: <Widget>[
                    Text('Makronutrien', style: textTheme.titleMedium),
                    const Spacer(),
                    Text(
                      formatPortionInUnit(_portion, _unit),
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
                    'Per 100 $_unit: ${formatKcal(food.per100g.caloriesKcal)} · '
                    'P ${formatGrams(food.per100g.proteinG)} · '
                    'K ${formatGrams(food.per100g.carbohydrateG)} · '
                    'L ${formatGrams(food.per100g.fatG)}',
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

String _categoryLabel(String category) => switch (category) {
  'beverage' => 'Minuman',
  'snack' => 'Camilan',
  'main' => 'Makanan utama',
  _ => 'Makanan',
};
