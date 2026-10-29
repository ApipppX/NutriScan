import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/brand_mark.dart';
import '../../../../core/widgets/offline_badge.dart';
import '../../../about/presentation/screens/about_screen.dart';
import '../../../daily_diary/domain/entities/diary_entry.dart';
import '../../../daily_diary/presentation/providers/diary_providers.dart';
import '../../../daily_diary/presentation/screens/diary_history_screen.dart';
import '../../../daily_diary/presentation/widgets/meal_type_sheet.dart';
import '../../domain/entities/scan_source.dart';
import '../controllers/scan_controller.dart';
import '../providers/scan_providers.dart';
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

  Future<void> _saveMeal(ScanSuccessState state) async {
    final candidate = state.result.selected;

    if (!await _confirmUncertainResult(state)) return;
    if (!mounted) return;

    final mealType = await showMealTypeSheet(
      context,
      candidate: candidate,
      portionGrams: state.effectivePortionGrams,
      facts: state.portionNutrition,
    );
    if (mealType == null || !mounted) return;

    try {
      final entry = await ref
          .read(diaryControllerProvider.notifier)
          .saveMeal(
            candidate: candidate,
            portionGrams: state.effectivePortionGrams,
            mealType: mealType,
            confidence: candidate.confidence,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              '${entry.displayName} disimpan ke ${entry.mealType.label} · '
              '${formatKcal(entry.caloriesKcal)}',
            ),
          ),
        );
    } catch (error, stackTrace) {
      AppLogger.error('Failed to save diary entry.', error, stackTrace);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan ke diary. Silakan coba lagi.'),
          ),
        );
    }
  }

  /// Requires explicit confirmation before a heuristically uncertain result is
  /// written to the diary. The classifier has no "unknown" class, so this is
  /// the point where the user acknowledges the limitation.
  Future<bool> _confirmUncertainResult(ScanSuccessState state) async {
    if (!state.result.needsReview) return true;

    final candidate = state.result.selected;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final scheme = Theme.of(context).colorScheme;
        final critical = state.result.isCriticallyUncertain;
        return AlertDialog(
          icon: Icon(
            critical
                ? Icons.report_problem_rounded
                : Icons.help_outline_rounded,
            color: critical ? scheme.error : scheme.tertiary,
          ),
          title: Text(
            critical
                ? 'Makanan mungkin tidak dikenali'
                : 'Hasil perlu diperiksa',
          ),
          content: Text(
            critical
                ? 'Model hanya yakin ${formatPercent(candidate.confidence)} '
                      'terhadap "${candidate.displayName}". Foto ini mungkin '
                      'bukan salah satu makanan yang didukung, sehingga nilai '
                      'gizinya berisiko tidak akurat.'
                : 'Keyakinan model ${formatPercent(candidate.confidence)} '
                      'dengan selisih prediksi teratas yang sempit. Pastikan '
                      '"${candidate.displayName}" memang makanan pada foto '
                      'sebelum menyimpannya.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Tetap simpan'),
            ),
          ],
        );
      },
    );
    return confirmed ?? false;
  }

  Future<void> _openDiary() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const DiaryHistoryScreen(),
      ),
    );
  }

  Future<void> _openAbout() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const AboutScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ScanState>(scanControllerProvider, _focusResult);
    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final diaryEntries =
        ref.watch(diaryControllerProvider).value ?? const <DiaryEntry>[];
    final todayEntryCount = diaryEntries
        .where((DiaryEntry entry) => entry.isSameDay(DateTime.now()))
        .length;

    return Scaffold(
      bottomNavigationBar: state is ScanSuccessState
          ? _DiaryActionBar(state: state, onSave: () => _saveMeal(state))
          : null,
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
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: _ScannerHeader(
                          todayEntryCount: todayEntryCount,
                          onOpenDiary: _openDiary,
                          onOpenAbout: _openAbout,
                        ),
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
        portionGrams: state.effectivePortionGrams,
        supportedFoods: ref.watch(nutritionRepositoryProvider).entries,
        onSelectCandidate: controller.selectCandidate,
        onPortionChanged: controller.setPortion,
        onRetake: () => controller.pickAndScan(ScanSource.camera),
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

/// Sticky bottom action bar that saves the current scan to the daily diary.
final class _DiaryActionBar extends StatelessWidget {
  const _DiaryActionBar({required this.state, required this.onSave});

  final ScanSuccessState state;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final macros = theme.extension<MacroColors>()!;
    final candidate = state.result.selected;
    final facts = state.portionNutrition;
    final unit = portionUnitForCategory(candidate.food.category);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.55)),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Center(
          // `heightFactor: 1` keeps the bar at its intrinsic height. Without it
          // `Center` expands to the Scaffold's full height, which starves the
          // body of space (the result page would render blank).
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final compact = constraints.maxWidth < 380;
                return Row(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: macros.caloriesContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.local_fire_department_rounded,
                        color: macros.calories,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            formatKcal(facts.caloriesKcal),
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: macros.calories,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${formatPortionInUnit(state.effectivePortionGrams, unit)} · '
                            '${formatPortionCount(candidate.food.portionCountFor(state.effectivePortionGrams))}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.icon(
                      onPressed: onSave,
                      icon: const Icon(Icons.bookmark_add_rounded, size: 19),
                      label: Text(compact ? 'Simpan' : 'Simpan ke Diary'),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

final class _ScannerHeader extends StatelessWidget {
  const _ScannerHeader({
    required this.todayEntryCount,
    required this.onOpenDiary,
    required this.onOpenAbout,
  });

  final int todayEntryCount;
  final VoidCallback onOpenDiary;
  final VoidCallback onOpenAbout;

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
            IconButton(
              tooltip: 'Riwayat diary',
              onPressed: onOpenDiary,
              icon: Badge.count(
                count: todayEntryCount,
                isLabelVisible: todayEntryCount > 0,
                child: const Icon(Icons.menu_book_rounded),
              ),
            ),
            IconButton(
              tooltip: 'Tentang NutriScan',
              onPressed: onOpenAbout,
              icon: const Icon(Icons.info_outline_rounded),
            ),
          ],
        ),
        const SizedBox(height: 24),
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
            Expanded(
              child: Text(
                'AI GIZI DI PERANGKAT',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const OfflineBadge(compact: true),
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
