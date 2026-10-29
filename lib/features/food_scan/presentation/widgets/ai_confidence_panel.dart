import 'package:flutter/material.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/utils/formatters.dart';

/// Confidence percentage bar with an inline retake action for weak scans.
final class AiConfidencePanel extends StatelessWidget {
  const AiConfidencePanel({
    super.key,
    required this.confidence,
    required this.onRetake,
    this.threshold = AppConfig.confidenceWarningThreshold,
  });

  final double confidence;
  final VoidCallback onRetake;
  final double threshold;

  bool get _isLow => confidence < threshold;

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
                  _isLow ? Icons.help_outline_rounded : Icons.verified_rounded,
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
                      'Seberapa yakin model mengenali makanan ini',
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
          if (_isLow) ...<Widget>[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(
                color: scheme.tertiaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: scheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Hasil masih kurang pasti. Ambil ulang foto dengan '
                          'pencahayaan lebih terang dan piring terlihat utuh.',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onTertiaryContainer,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.tonalIcon(
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
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _levelColor(ColorScheme scheme) {
    if (_isLow) return scheme.error;
    if (confidence < 0.8) return scheme.tertiary;
    return scheme.primary;
  }

  String _levelLabel() {
    if (_isLow) return 'Rendah';
    if (confidence < 0.8) return 'Cukup';
    return 'Tinggi';
  }
}
