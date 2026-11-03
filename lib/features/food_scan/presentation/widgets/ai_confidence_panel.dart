import 'package:flutter/material.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/utils/formatters.dart';

/// Confidence percentage bar with an inline review/retake action for weak
/// scans.
///
/// The classifier is closed-set: it always returns one of the supported foods.
/// Low confidence and a narrow top-1/top-2 gap are therefore used as heuristic
/// signals that the photo may not contain a supported food at all.
final class AiConfidencePanel extends StatelessWidget {
  const AiConfidencePanel({
    super.key,
    required this.confidence,
    required this.onRetake,
    required this.onShowSupportedFoods,
    this.margin,
    this.topThreeMass,
    this.supportedCount,
    this.isManualSelection = false,
    this.threshold = AppConfig.confidenceWarningThreshold,
  });

  /// Confidence of the currently selected candidate.
  final double confidence;

  /// Top-1 minus top-2 confidence. Null when there is only one candidate.
  final double? margin;

  /// Total probability of the returned top-3 candidates.
  final double? topThreeMass;

  /// Number of menu classes in the bundled closed-set model.
  final int? supportedCount;

  final VoidCallback onRetake;
  final VoidCallback onShowSupportedFoods;
  final bool isManualSelection;
  final double threshold;

  bool get _isLow => confidence < threshold;

  bool get _isAmbiguous =>
      margin != null && margin! < AppConfig.confidenceMarginThreshold;

  bool get _isDiffuse =>
      topThreeMass != null && topThreeMass! < AppConfig.topThreeMassThreshold;

  bool get _isCritical => confidence < AppConfig.confidenceCriticalThreshold;

  bool get _needsReview =>
      !isManualSelection && (_isLow || _isAmbiguous || _isDiffuse);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final levelColor = _levelColor(scheme);
    final levelLabel = _levelLabel();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  _needsReview
                      ? Icons.help_outline_rounded
                      : Icons.verified_rounded,
                  size: 18,
                  color: levelColor,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Keyakinan AI',
                      style: textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isManualSelection
                          ? 'Keyakinan model untuk alternatif pilihan Anda'
                          : 'Seberapa yakin model mengenali makanan ini',
                      style: textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  levelLabel,
                  style: textTheme.labelSmall?.copyWith(
                    color: levelColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                formatPercent(confidence),
                style: textTheme.headlineSmall?.copyWith(
                  color: levelColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ambang peringatan '
                  '${formatPercent(threshold, decimals: 0)}',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final marker = (threshold * constraints.maxWidth)
                  .clamp(0.0, constraints.maxWidth)
                  .toDouble();
              return Stack(
                clipBehavior: Clip.none,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: confidence.clamp(0.0, 1.0),
                      minHeight: 9,
                      color: levelColor,
                      backgroundColor: levelColor.withValues(alpha: 0.14),
                    ),
                  ),
                  Positioned(
                    left: marker - 0.75,
                    top: -2,
                    bottom: -2,
                    child: Container(
                      width: 1.5,
                      decoration: BoxDecoration(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          if (supportedCount != null) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.dataset_outlined,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Model hanya mengenali $supportedCount menu dari dataset; '
                    'makanan lain bisa salah diklasifikasi.',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (_needsReview) ...<Widget>[
            const SizedBox(height: 14),
            _ReviewCallout(
              isCritical: _isCritical,
              isAmbiguous: _isAmbiguous && !_isLow,
              isDiffuse: _isDiffuse && !_isLow && !_isAmbiguous,
              supportedCount: supportedCount,
              onRetake: onRetake,
              onShowSupportedFoods: onShowSupportedFoods,
            ),
          ] else if (isManualSelection) ...<Widget>[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.touch_app_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Anda memilih alternatif secara manual. Periksa kembali '
                    'kecocokannya sebelum menyimpan ke diary.',
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _levelColor(ColorScheme scheme) {
    if (_isCritical || _isLow) return scheme.error;
    if (_isAmbiguous || _isDiffuse || confidence < 0.8) return scheme.tertiary;
    return scheme.primary;
  }

  String _levelLabel() {
    if (_isCritical) return 'Sangat rendah';
    if (_isLow) return 'Rendah';
    if (_isAmbiguous) return 'Ambigu';
    if (_isDiffuse) return 'Tersebar';
    if (confidence < 0.8) return 'Cukup';
    return 'Tinggi';
  }
}

final class _ReviewCallout extends StatelessWidget {
  const _ReviewCallout({
    required this.isCritical,
    required this.isAmbiguous,
    required this.isDiffuse,
    required this.supportedCount,
    required this.onRetake,
    required this.onShowSupportedFoods,
  });

  final bool isCritical;
  final bool isAmbiguous;
  final bool isDiffuse;
  final int? supportedCount;
  final VoidCallback onRetake;
  final VoidCallback onShowSupportedFoods;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = isCritical
        ? scheme.errorContainer.withValues(alpha: 0.42)
        : scheme.tertiaryContainer.withValues(alpha: 0.55);
    final foreground = isCritical
        ? scheme.onErrorContainer
        : scheme.onTertiaryContainer;
    final countText = supportedCount == null ? '' : ' ($supportedCount menu)';
    final title = isCritical
        ? 'Kemungkinan bukan menu yang didukung'
        : isDiffuse
        ? 'Prediksi tersebar'
        : 'Hasil perlu diperiksa';
    final body = isCritical
        ? 'Keyakinan model sangat rendah. Foto ini mungkin bukan salah satu '
              'makanan yang didukung$countText. Hasil dan nilai gizinya '
              'berisiko tidak valid.'
        : isDiffuse
        ? 'Model mempertimbangkan banyak menu sekaligus. Foto mungkin bukan '
              'menu yang didukung, atau objeknya kurang jelas. Periksa daftar '
              'menu atau foto ulang sebelum menyimpan.'
        : isAmbiguous
        ? 'Dua prediksi teratas hampir sama kuat. Pilih alternatif yang paling '
              'sesuai, periksa daftar menu, atau foto ulang.'
        : 'Keyakinan model rendah. NutriScan hanya mengenali menu di dataset, '
              'jadi hasil teratas bisa salah. Periksa daftar menu atau foto '
              'ulang.';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                isCritical
                    ? Icons.report_problem_rounded
                    : Icons.info_outline_rounded,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final listButton = OutlinedButton.icon(
                onPressed: onShowSupportedFoods,
                style: OutlinedButton.styleFrom(
                  foregroundColor: foreground,
                  side: BorderSide(color: foreground.withValues(alpha: 0.45)),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: const Text('Daftar makanan'),
              );
              final retakeButton = FilledButton.tonalIcon(
                onPressed: onRetake,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: const Text('Foto Ulang'),
              );

              if (constraints.maxWidth < 320) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    listButton,
                    const SizedBox(height: 8),
                    retakeButton,
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(child: listButton),
                  const SizedBox(width: 8),
                  Expanded(child: retakeButton),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
