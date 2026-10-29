import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/entities/nutrition_facts.dart';

/// Two-reference nutrition table: the current portion and the catalog's
/// per-100 g (or per-100 ml) values.
///
/// The table is intentionally self-contained so the result card and the detail
/// sheet present exactly the same numbers and wording.
final class NutritionSummaryTable extends StatelessWidget {
  const NutritionSummaryTable({
    super.key,
    required this.portionFacts,
    required this.per100g,
    required this.unit,
    this.showCaption = true,
  });

  /// Nutrition for the currently selected portion.
  final NutritionFacts portionFacts;

  /// Catalog values per 100 g (or 100 ml for beverages).
  final NutritionFacts per100g;

  /// Portion unit: `g` or `ml`.
  final String unit;

  /// Shows the calculation/provenance note below the table.
  final bool showCaption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final macros = theme.extension<MacroColors>()!;
    final rows = <_NutrientRowData>[
      _NutrientRowData(
        label: 'Energi',
        portion: formatKcal(portionFacts.caloriesKcal),
        reference: formatKcal(per100g.caloriesKcal),
        color: macros.calories,
        emphasize: true,
      ),
      _NutrientRowData(
        label: 'Protein',
        portion: formatGrams(portionFacts.proteinG),
        reference: formatGrams(per100g.proteinG),
        share: portionFacts.energyShare(MacroNutrient.protein),
        color: macros.protein,
      ),
      _NutrientRowData(
        label: 'Karbohidrat',
        portion: formatGrams(portionFacts.carbohydrateG),
        reference: formatGrams(per100g.carbohydrateG),
        share: portionFacts.energyShare(MacroNutrient.carbohydrates),
        color: macros.carbohydrates,
      ),
      _NutrientRowData(
        label: 'Lemak',
        portion: formatGrams(portionFacts.fatG),
        reference: formatGrams(per100g.fatG),
        share: portionFacts.energyShare(MacroNutrient.fat),
        color: macros.fat,
      ),
      _NutrientRowData(
        label: 'Serat',
        portion: formatGrams(portionFacts.fiberG),
        reference: formatGrams(per100g.fiberG),
        color: scheme.tertiary,
      ),
      _NutrientRowData(
        label: 'Natrium',
        portion: formatMilligrams(portionFacts.sodiumMg),
        reference: formatMilligrams(per100g.sodiumMg),
        color: scheme.secondary,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _HeaderRow(unit: unit),
          for (var index = 0; index < rows.length; index++) ...<Widget>[
            if (index > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.45),
              ),
            _NutrientRow(data: rows[index], unit: unit),
          ],
          if (showCaption) ...<Widget>[
            Divider(
              height: 1,
              thickness: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.45),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 14,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Per porsi dihitung dari nilai per 100 $unit. '
                      'Estimasi katalog, bukan analisis laboratorium.',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.unit});

  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final style = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.5,
    );

    return Container(
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.55),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: <Widget>[
          Expanded(flex: 5, child: Text('ZAT GIZI', style: style)),
          Expanded(
            flex: 3,
            child: Text('PER PORSI', textAlign: TextAlign.end, style: style),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'PER 100 ${unit.toUpperCase()}',
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

final class _NutrientRowData {
  const _NutrientRowData({
    required this.label,
    required this.portion,
    required this.reference,
    required this.color,
    this.share,
    this.emphasize = false,
  });

  final String label;
  final String portion;
  final String reference;
  final Color color;
  final double? share;
  final bool emphasize;
}

final class _NutrientRow extends StatelessWidget {
  const _NutrientRow({required this.data, required this.unit});

  final _NutrientRowData data;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final numericStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w800,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    final referenceStyle = theme.textTheme.labelMedium?.copyWith(
      color: scheme.onSurfaceVariant,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );

    return Semantics(
      label:
          '${data.label}: ${data.portion} per porsi, '
          '${data.reference} per 100 $unit'
          '${data.share == null ? '' : ', ${formatPercent(data.share!, decimals: 0)} energi'}.',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(
              flex: 5,
              child: Row(
                children: <Widget>[
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: data.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      data.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: data.emphasize
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    data.portion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: numericStyle,
                  ),
                  if (data.share != null)
                    Text(
                      '${formatPercent(data.share!, decimals: 0)} energi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: data.color.withValues(alpha: 0.85),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(
                data.reference,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: referenceStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
