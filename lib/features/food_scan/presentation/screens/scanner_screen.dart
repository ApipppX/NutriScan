import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/offline_badge.dart';
import '../../domain/entities/scan_source.dart';
import '../controllers/scan_controller.dart';
import '../state/scan_state.dart';
import '../widgets/scan_failure_card.dart';
import '../widgets/scan_result_card.dart';
import '../widgets/scan_stage_card.dart';
import '../widgets/scanner_onboarding.dart';

/// Main scanner page. Reads the [ScanController] state and composes the hero
/// stage card with the appropriate result, error, or onboarding content.
final class ScannerScreen extends ConsumerStatefulWidget {
  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

final class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _contentAnchorKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _focusResult(ScanState? previous, ScanState next) {
    final enteredResult =
        next is ScanSuccessState && previous is! ScanSuccessState;
    final enteredFailure =
        next is ScanFailureState && previous is! ScanFailureState;
    if (enteredResult || enteredFailure) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final anchorContext = _contentAnchorKey.currentContext;
        if (anchorContext == null) return;
        Scrollable.ensureVisible(
          anchorContext,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
          alignment: 0.02,
        );
      });
    } else if (next is ScanIdle && previous is! ScanIdle) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ScanState>(scanControllerProvider, _focusResult);
    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned(
            top: -150,
            right: -120,
            child: IgnorePointer(
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      scheme.primary.withValues(alpha: 0.14),
                      scheme.primary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 360,
            left: -170,
            child: IgnorePointer(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: <Color>[
                      scheme.tertiary.withValues(alpha: 0.07),
                      scheme.tertiary.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const ClampingScrollPhysics(),
                  slivers: <Widget>[
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: _ScannerHeader(),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        24,
                        20,
                        32 + MediaQuery.paddingOf(context).bottom,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate(<Widget>[
                          ScanStageCard(
                            state: state,
                            onCamera: () =>
                                controller.pickAndScan(ScanSource.camera),
                            onGallery: () =>
                                controller.pickAndScan(ScanSource.gallery),
                          ),
                          const SizedBox(height: 16),
                          KeyedSubtree(
                            key: _contentAnchorKey,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 320),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder:
                                  (Widget child, Animation<double> animation) {
                                    final offset = Tween<Offset>(
                                      begin: const Offset(0, 0.025),
                                      end: Offset.zero,
                                    ).animate(animation);
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: offset,
                                        child: child,
                                      ),
                                    );
                                  },
                              child: _buildContent(state, controller),
                            ),
                          ),
                          if (state is ScanIdle) ...<Widget>[
                            const SizedBox(height: 16),
                            const ScannerOnboarding(),
                          ],
                          const SizedBox(height: 22),
                          _Disclaimer(scheme: scheme),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ScanState state, ScanController controller) {
    return switch (state) {
      ScanSuccessState() => ScanResultCard(
        key: ValueKey<String>('result-${state.result.selected.label}'),
        result: state.result,
        onSelectCandidate: controller.selectCandidate,
        onScanAgain: controller.reset,
      ),
      ScanFailureState() => ScanFailureCard(
        key: ValueKey<String>('failure-${state.message}'),
        state: state,
        onRetry: controller.retry,
        onCamera: () => controller.pickAndScan(ScanSource.camera),
        onGallery: () => controller.pickAndScan(ScanSource.gallery),
      ),
      ScanIdle() => const SizedBox.shrink(key: ValueKey<String>('idle')),
      ScanProcessing() => const SizedBox.shrink(
        key: ValueKey<String>('processing'),
      ),
    };
  }
}

final class _ScannerHeader extends StatelessWidget {
  const _ScannerHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            const BrandMark(size: 42),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'NutriScan',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  Text(
                    'Asisten gizi offline',
                    style: textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const OfflineBadge(compact: true),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          children: <Widget>[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: scheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              'AI GIZI DI PERANGKAT',
              style: textTheme.labelSmall?.copyWith(
                color: scheme.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text.rich(
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(text: 'Kenali makananmu,\n'),
                TextSpan(
                  text: 'ketahui gizinya.',
                  style: TextStyle(color: scheme.primary),
                ),
              ],
            ),
            style: textTheme.headlineMedium?.copyWith(
              fontSize: 34,
              height: 1.1,
              letterSpacing: -1.1,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Foto makananmu dan dapatkan estimasi kalori serta makronutrien dalam '
          'hitungan detik. Semua diproses lokal, tanpa upload.',
          style: textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

final class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      'NutriScan bukan alat medis. Nilai gizi adalah estimasi dan dapat berbeda '
      'tergantung resep serta ukuran porsi.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
        height: 1.45,
      ),
    );
  }
}
