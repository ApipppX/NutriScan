import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/entities/food_nutrition.dart';

/// Serving-size stepper with quick portion presets.
///
/// The widget is intentionally stateless: the selected grams live in the scan
/// controller so the result card, diary bar, and save sheet stay in sync.
final class PortionSelector extends StatelessWidget {
  const PortionSelector({
    super.key,
    required this.food,
    required this.portionGrams,
    required this.onChanged,
    this.stepGrams = 10,
  });

  final FoodNutrition food;
  final int portionGrams;
  final ValueChanged<int> onChanged;
  final int stepGrams;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final unit = portionUnitForCategory(food.category);
    final canDecrease = portionGrams > food.minimumPortionGrams;
    final canIncrease = portionGrams < food.maximumPortionGrams;
    final portionCount = food.portionCountFor(portionGrams);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text('Ukuran porsi', style: textTheme.titleMedium),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                formatPortionCount(portionCount),
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
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
                    onPressed: canDecrease
                        ? () => onChanged(portionGrams - stepGrams)
                        : null,
                    tooltip: 'Kurangi porsi',
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Expanded(
                    child: Column(
                      children: <Widget>[
                        Semantics(
                          label:
                              'Porsi saat ini '
                              '${formatPortionInUnit(portionGrams, unit)}',
                          liveRegion: true,
                          child: Text(
                            formatPortionInUnit(portionGrams, unit),
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '1 porsi = '
                          '${formatPortionInUnit(food.defaultPortionGrams, unit)}',
                          style: textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: canIncrease
                        ? () => onChanged(portionGrams + stepGrams)
                        : null,
                    tooltip: 'Tambah porsi',
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value:
                      ((portionGrams - food.minimumPortionGrams) /
                              (food.maximumPortionGrams -
                                  food.minimumPortionGrams))
                          .clamp(0.0, 1.0),
                  minHeight: 5,
                  color: scheme.primary,
                  backgroundColor: scheme.primary.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            for (final preset in const <double>[0.5, 1, 1.5, 2])
              _PortionPresetChip(
                label: _presetLabel(preset),
                selected:
                    (portionGrams -
                            food.clampPortion(
                              food.gramsForPortionCount(preset),
                            ))
                        .abs() <=
                    stepGrams ~/ 2,
                onTap: () => onChanged(
                  food.clampPortion(food.gramsForPortionCount(preset)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _presetLabel(double count) => switch (count) {
    0.5 => '½ porsi',
    1 => '1 porsi',
    1.5 => '1½ porsi',
    2 => '2 porsi',
    _ => formatPortionCount(count),
  };
}

final class _PortionPresetChip extends StatelessWidget {
  const _PortionPresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (value) {
        if (value) onTap();
      },
      label: Text(label),
      side: BorderSide(
        color: selected
            ? scheme.primary.withValues(alpha: 0.5)
            : scheme.outlineVariant.withValues(alpha: 0.55),
      ),
    );
  }
}
