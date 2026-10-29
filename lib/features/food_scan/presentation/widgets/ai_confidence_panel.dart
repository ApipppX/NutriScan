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
    this.isManualSelection = false,
    this.threshold = AppConfig.confidenceWarningThreshold,
  });

  /// Confidence of the currently selected candidate.
  final double confidence;

  /// Top-1 minus top-2 confidence. Null when there is only one candidate.
  final double? margin;

  final VoidCallback onRetake;
  final VoidCallback onShowSupportedFoods;
  final bool isManualSelection;
  final double threshold;

  bool get _isLow => confidence < threshold;

  bool get _isAmbiguous =>
      margin != null && margin! < AppConfig.confidenceMarginThreshold;

  bool get _isCritical => confidence < AppConfig.confidenceCriticalThreshold;

  bool get _needsReview => !isManualSelection && (_isLow || _isAmbiguous);

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
                  'Ambang aman ${formatPercent(threshold, decimals: 0)}',
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
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: confidence.clamp(0.0, 1.0),
              minHeight: 9,
              color: levelColor,
              backgroundColor: levelColor.withValues(alpha: 0.14),
            ),
          ),
          if (_needsReview) ...<Widget>[
            const SizedBox(height: 14),
            _ReviewCallout(
              isCritical: _isCritical,
              isAmbiguous: _isAmbiguous && !_isLow,
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
    if (_isAmbiguous || confidence < 0.8) return scheme.tertiary;
    return scheme.primary;
  }

  String _levelLabel() {
    if (_isCritical) return 'Sangat rendah';
    if (_isLow) return 'Rendah';
    if (_isAmbiguous) return 'Ambigu';
    if (confidence < 0.8) return 'Cukup';
    return 'Tinggi';
  }
}

final class _ReviewCallout extends StatelessWidget {
  const _ReviewCallout({
    required this.isCritical,
    required this.isAmbiguous,
    required this.onRetake,
    required this.onShowSupportedFoods,
  });

  final bool isCritical;
  final bool isAmbiguous;
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
    final title = isCritical
        ? 'Makanan mungkin tidak dikenali'
        : 'Hasil perlu diperiksa';
    final body = isCritical
        ? 'Model tidak cukup yakin. Foto ini mungkin bukan salah satu makanan '
              'yang didukung. Jangan gunakan nilai gizinya tanpa memeriksa '
              'ulang.'
        : isAmbiguous
        ? 'Dua prediksi teratas hampir sama kuat. Pilih alternatif yang paling '
              'sesuai atau foto ulang.'
        : 'Keyakinan model rendah. NutriScan hanya mengenali makanan di daftar '
              'dukungan, jadi hasil teratas bisa salah.';

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
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 4,
            children: <Widget>[
              OutlinedButton.icon(
                onPressed: onShowSupportedFoods,
                style: OutlinedButton.styleFrom(
                  foregroundColor: foreground,
                  side: BorderSide(color: foreground.withValues(alpha: 0.45)),
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                label: const Text('Daftar makanan'),
              ),
              FilledButton.tonalIcon(
                onPressed: onRetake,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: const Text('Foto Ulang'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
