import 'package:flutter/material.dart';

import '../../../../core/localization/food_label_localizer.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../food_scan/domain/entities/food_candidate.dart';
import '../../../food_scan/domain/entities/nutrition_facts.dart';
import '../../domain/entities/meal_type.dart';

/// Shows the "save to diary" category picker and returns the selected meal.
Future<MealType?> showMealTypeSheet(
  BuildContext context, {
  required FoodCandidate candidate,
  required int portionGrams,
  required NutritionFacts facts,
}) {
  return showModalBottomSheet<MealType>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) => _MealTypeSheet(
      candidate: candidate,
      portionGrams: portionGrams,
      facts: facts,
    ),
  );
}

final class _MealTypeSheet extends StatefulWidget {
  const _MealTypeSheet({
    required this.candidate,
    required this.portionGrams,
    required this.facts,
  });

  final FoodCandidate candidate;
  final int portionGrams;
  final NutritionFacts facts;

  @override
  State<_MealTypeSheet> createState() => _MealTypeSheetState();
}

final class _MealTypeSheetState extends State<_MealTypeSheet> {
  late MealType _selected = MealType.forTime(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final macros = theme.extension<MacroColors>()!;
    final food = widget.candidate.food;
    final unit = portionUnitForCategory(food.category);
    final displayName = FoodLabelLocalizer.resolve(
      food.label,
      displayName: food.displayName,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text('Simpan ke Diary', style: textTheme.headlineSmall),
                const SizedBox(height: 4),
                Text(
                  'Pilih waktu makan agar asupan harianmu tercatat rapi.',
                  style: textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: macros.caloriesContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          food.emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${formatPortionInUnit(widget.portionGrams, unit)} · '
                              '${formatKcal(widget.facts.caloriesKcal)}',
                              style: textTheme.bodySmall?.copyWith(
                                color: macros.calories,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('Waktu makan', style: textTheme.titleMedium),
                const SizedBox(height: 10),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.55,
                  children: <Widget>[
                    for (final meal in MealType.values)
                      _MealOptionCard(
                        meal: meal,
                        selected: meal == _selected,
                        onTap: () => setState(() => _selected = meal),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(_selected),
                  icon: const Icon(Icons.bookmark_add_rounded, size: 20),
                  label: Text('Simpan ke ${_selected.label}'),
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Batal'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _MealOptionCard extends StatelessWidget {
  const _MealOptionCard({
    required this.meal,
    required this.selected,
    required this.onTap,
  });

  final MealType meal;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final background = selected
        ? scheme.primaryContainer
        : scheme.surfaceContainerLow;
    final foreground = selected
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Semantics(
      button: true,
      selected: selected,
      label: '${meal.label}, ${meal.windowLabel}',
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.65)
                    : scheme.outlineVariant.withValues(alpha: 0.55),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(meal.icon, size: 22, color: foreground),
                    const Spacer(),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: scheme.primary,
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      meal.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(color: foreground),
                    ),
                    Text(
                      meal.windowLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelSmall?.copyWith(
                        color: foreground.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

extension on MealType {
  IconData get icon => switch (this) {
    MealType.breakfast => Icons.free_breakfast_rounded,
    MealType.lunch => Icons.lunch_dining_rounded,
    MealType.dinner => Icons.dinner_dining_rounded,
    MealType.snack => Icons.cookie_rounded,
  };
}
