import 'package:flutter/material.dart';

import '../../../../core/localization/food_label_localizer.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/food_nutrition.dart';

/// Shows every food the bundled model can recognize.
///
/// This is the honest fallback for a closed-set classifier: if the user's food
/// is absent from this list, no amount of confidence tuning can make the
/// prediction valid.
Future<void> showSupportedFoodsSheet(
  BuildContext context, {
  required List<FoodNutrition> foods,
  String? selectedLabel,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (BuildContext context) =>
        _SupportedFoodsSheet(foods: foods, selectedLabel: selectedLabel),
  );
}

final class _SupportedFoodsSheet extends StatelessWidget {
  const _SupportedFoodsSheet({required this.foods, this.selectedLabel});

  final List<FoodNutrition> foods;
  final String? selectedLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sorted = List<FoodNutrition>.of(foods)
      ..sort((FoodNutrition a, FoodNutrition b) {
        final byCategory = _categoryRank(a.category)
            .compareTo(_categoryRank(b.category));
        if (byCategory != 0) return byCategory;
        return FoodLabelLocalizer.resolve(
          a.label,
          displayName: a.displayName,
        ).compareTo(
          FoodLabelLocalizer.resolve(b.label, displayName: b.displayName),
        );
      });

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 12, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.restaurant_menu_rounded,
                      color: scheme.onPrimaryContainer,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Makanan yang didukung',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${foods.length} kelas dalam model ini',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Tutup',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 10),
              child: Text(
                'NutriScan hanya mengenali makanan di daftar ini. Jika '
                'makananmu tidak ada di sini, hasil scan tidak dapat '
                'dipercaya.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.all(22),
                child: Text('Daftar makanan belum tersedia.'),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  itemCount: sorted.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      Divider(
                        height: 1,
                        indent: 64,
                        color: scheme.outlineVariant.withValues(alpha: 0.45),
                      ),
                  itemBuilder: (BuildContext context, int index) {
                    final food = sorted[index];
                    final selected = food.label == selectedLabel;
                    final unit = portionUnitForCategory(food.category);
                    final displayName = FoodLabelLocalizer.resolve(
                      food.label,
                      displayName: food.displayName,
                    );
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      tileColor: selected
                          ? scheme.primaryContainer.withValues(alpha: 0.45)
                          : null,
                      leading: Text(
                        food.emoji,
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${categoryLabel(food.category)} · '
                        'porsi saji ${formatPortionInUnit(food.defaultPortionGrams, unit)}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: selected
                          ? Icon(
                              Icons.check_circle_rounded,
                              color: scheme.primary,
                              size: 20,
                            )
                          : null,
                    );
                  },
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
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
                        'Model belum memiliki kelas "tidak dikenal". '
                        'Peringatan muncul dari keyakinan rendah dan selisih '
                        'prediksi, bukan dari deteksi otomatis makanan asing.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _categoryRank(String category) => switch (category) {
    'main' => 0,
    'snack' => 1,
    'beverage' => 2,
    _ => 3,
  };
}
