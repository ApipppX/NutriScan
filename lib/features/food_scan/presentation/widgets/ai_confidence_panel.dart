import 'package:flutter/material.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/utils/formatters.dart';

/// Confidence percentage bar with an inline review/retake action for weak
/// scans.
///
/// The classifier is closed-set: it always returns one of the supported foods.
/// Low confidence and a narrow top-1/top-2 gap are therefore used as heuristic
/// signals that the photo may not contain a supported food at all.
final class AiConfidencePanel extends StatefulWidget {
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

  @override
  State<AiConfidencePanel> createState() => _AiConfidencePanelState();
}

class _AiConfidencePanelState extends State<AiConfidencePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLow => widget.confidence < widget.threshold;

  bool get _isAmbiguous =>
      widget.margin != null &&
      widget.margin! < AppConfig.confidenceMarginThreshold;

  bool get _isDiffuse =>
      widget.topThreeMass != null &&
      widget.topThreeMass! < AppConfig.topThreeMassThreshold;

  bool get _isCritical =>
      widget.confidence < AppConfig.confidenceCriticalThreshold;

  bool get _needsReview =>
      !widget.isManualSelection && (_isLow || _isAmbiguous || _isDiffuse);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final levelColor = _levelColor(scheme);
    final levelLabel = _levelLabel();
    final needsReview = _needsReview;
    final isCritical = _isCritical;
    final isAmbiguous = _isAmbiguous && !isCritical;
    final isDiffuse = _isDiffuse && !isCritical && !isAmbiguous;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Keyakinan AI',
                          style: textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          levelLabel,
                          style: textTheme.titleSmall?.copyWith(
                            color: levelColor,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          formatPercent(widget.confidence, decimals: 1),
                          style: textTheme.headlineSmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(
                              Icons.question_answer_rounded,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Ambang ${formatPercent(widget.threshold, decimals: 0)}',
                              textAlign: TextAlign.end,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final marker = (widget.threshold * constraints.maxWidth)
                      .clamp(0.0, constraints.maxWidth)
                      .toDouble();
                  return Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: widget.confidence.clamp(0.0, 1.0),
                          minHeight: 10,
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
              if (widget.supportedCount != null) ...<Widget>[
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
                        'Model hanya mengenali ${widget.supportedCount} menu dari dataset; '
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
              if (needsReview) ...<Widget>[
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(
                      sizeFactor: animation,
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey<bool>(needsReview),
                    child: _ReviewCallout(
                      isCritical: isCritical,
                      isAmbiguous: isAmbiguous,
                      isDiffuse: isDiffuse,
                      supportedCount: widget.supportedCount,
                      onRetake: widget.onRetake,
                      onShowSupportedFoods: widget.onShowSupportedFoods,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _levelLabel() {
    if (_isCritical) return 'Sangat rendah';
    if (_isDiffuse) return 'Tersebar';
    if (_isAmbiguous) return 'Ambigu';
    if (_isLow) return 'Rendah';
    if (widget.confidence < 0.8) return 'Cukup';
    return 'Tinggi';
  }

  Color _levelColor(ColorScheme scheme) {
    if (_isCritical || _isDiffuse || widget.confidence < 0.6) {
      return scheme.error;
    }
    if (_isAmbiguous || widget.confidence < 0.8) return scheme.tertiary;
    return scheme.primary;
  }
}

/// Warning callout with review/retake actions for uncertain scans.
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
    final textTheme = theme.textTheme;
    final foreground = isCritical ? scheme.onError : scheme.onTertiaryContainer;
    final background = isCritical
        ? scheme.errorContainer
        : scheme.tertiaryContainer.withValues(alpha: 0.4);
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
        border: Border.all(
          color: (isCritical ? scheme.error : scheme.tertiary)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                isCritical ? Icons.warning_rounded : Icons.info_rounded,
                size: 17,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      body,
                      style: textTheme.labelSmall?.copyWith(
                        color: foreground.withValues(alpha: 0.85),
                        height: 1.5,
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
