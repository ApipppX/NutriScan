import 'package:flutter/material.dart';

/// Compact label that distinguishes catalog-based nutrition estimates from
/// model predictions.
///
/// The classifier predicts a food class; nutrition is calculated
/// deterministically from the catalog and the chosen portion. When the result
/// still needs review, [provisional] switches the label to an explicit
/// temporary-estimate state.
final class NutritionEstimateBadge extends StatelessWidget {
  const NutritionEstimateBadge({
    super.key,
    this.provisional = false,
    this.compact = false,
  });

  /// Marks the estimate as temporary because the food class is uncertain.
  final bool provisional;

  /// Drops the icon to save horizontal space.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = provisional
        ? scheme.onTertiaryContainer
        : scheme.onSecondaryContainer;
    final background = provisional
        ? scheme.tertiaryContainer
        : scheme.secondaryContainer;
    final label = provisional ? 'Estimasi sementara' : 'Estimasi';
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (!compact) ...<Widget>[
          Icon(
            provisional
                ? Icons.hourglass_top_rounded
                : Icons.calculate_outlined,
            size: 13,
            color: foreground,
          ),
          const SizedBox(width: 5),
        ],
        Text(
          label,
          maxLines: 1,
          softWrap: false,
          style: theme.textTheme.labelSmall?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );

    return Semantics(
      label: provisional
          ? 'Estimasi gizi sementara, jenis makanan belum terverifikasi'
          : 'Estimasi gizi dari katalog, bukan analisis laboratorium',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            if (!constraints.hasBoundedWidth) return content;
            // Shrink slightly instead of overflowing when the result header
            // is narrow or the user has a large text scale.
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: content,
            );
          },
        ),
      ),
    );
  }
}
