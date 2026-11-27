import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../food_scan/domain/entities/nutrition_facts.dart';
import '../../../user_profile/domain/entities/user_profile.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/entities/exercise_recommendation.dart';
import '../providers/diary_providers.dart';
import '../providers/exercise_providers.dart';

/// Chronological diary view with daily calorie and macronutrient totals.
final class DiaryHistoryScreen extends ConsumerWidget {
  const DiaryHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diary = ref.watch(diaryControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Riwayat Diary')),
      body: SafeArea(
        top: false,
        child: diary.when(
          data: (List<DiaryEntry> entries) => entries.isEmpty
              ? const _EmptyDiaryState()
              : _DiaryHistoryList(entries: entries),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => _DiaryErrorState(
            onRetry: () => ref.invalidate(diaryControllerProvider),
          ),
        ),
      ),
    );
  }
}

final class _DiaryHistoryList extends ConsumerStatefulWidget {
  const _DiaryHistoryList({required this.entries});

  final List<DiaryEntry> entries;

  @override
  ConsumerState<_DiaryHistoryList> createState() => _DiaryHistoryListState();
}

class _DiaryHistoryListState extends ConsumerState<_DiaryHistoryList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupEntriesByDay(widget.entries);
    final recommendation = ref.watch(exerciseRecommendationProvider);
    final today = DateTime.now();
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
          itemCount: groups.length + 1,
          separatorBuilder: (BuildContext context, int index) =>
              const SizedBox(height: 14),
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) return const _LocalStorageNotice();
            final group = groups[index - 1];
            final isToday = _isSameDay(group.day, today);

            return AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final opacity = CurvedAnimation(
                  parent: _controller,
                  curve: Interval(
                    (index / (groups.length + 1)).clamp(0.0, 1.0),
                    ((index + 1) / (groups.length + 1)).clamp(0.0, 1.0),
                    curve: Curves.easeOutCubic,
                  ),
                ).value;
                return Opacity(opacity: opacity, child: child);
              },
              child: _DayCard(
                group: group,
                recommendation: isToday ? recommendation : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _DayCard extends StatelessWidget {
  const _DayCard({required this.group, this.recommendation});

  final _DayGroup group;
  final AsyncValue<DailyExerciseRecommendation>? recommendation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final totals = group.entries.fold(
      NutritionFacts.zero,
      (NutritionFacts sum, DiaryEntry entry) => sum + entry.nutrition,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    Icons.calendar_today_rounded,
                    size: 17,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    formatDiaryDay(group.day),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${group.entries.length} catatan',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DailyTotals(facts: totals),
            if (recommendation != null) ...[
              const SizedBox(height: 12),
              recommendation!.when(
                data: (DailyExerciseRecommendation value) =>
                    _ExerciseRecommendationSection(recommendation: value),
                loading: () => const SizedBox.shrink(),
                error: (Object error, StackTrace stackTrace) =>
                    const SizedBox.shrink(),
              ),
            ],
            const SizedBox(height: 6),
            for (var index = 0; index < group.entries.length; index++) ...[
              if (index > 0) const Divider(height: 1),
              _DiaryEntryTile(entry: group.entries[index]),
            ],
          ],
        ),
      ),
    );
  }
}

final class _DailyTotals extends StatelessWidget {
  const _DailyTotals({required this.facts});

  final NutritionFacts facts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final macros = theme.extension<MacroColors>()!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            macros.caloriesContainer.withValues(alpha: 0.85),
            macros.caloriesContainer.withValues(alpha: 0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: macros.calories.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.local_fire_department_rounded,
                size: 18,
                color: macros.calories,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Total harian',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatKcal(facts.caloriesKcal),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: macros.calories,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: <Widget>[
              _MacroPill(
                label: 'Protein',
                value: formatGrams(facts.proteinG),
                color: macros.protein,
              ),
              _MacroPill(
                label: 'Karbo',
                value: formatGrams(facts.carbohydrateG),
                color: macros.carbohydrates,
              ),
              _MacroPill(
                label: 'Lemak',
                value: formatGrams(facts.fatG),
                color: macros.fat,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _MacroPill extends StatelessWidget {
  const _MacroPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$label ',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: value,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _DiaryEntryTile extends StatelessWidget {
  const _DiaryEntryTile({required this.entry});

  final DiaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final macros = theme.extension<MacroColors>()!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.1)),
            ),
            child: Text(entry.emoji, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${entry.mealType.label} · ${formatClockTime(entry.loggedAt)} · '
                  '${formatPortionInUnit(entry.portionGrams, entry.portionUnit)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            formatKcal(entry.caloriesKcal),
            style: theme.textTheme.labelMedium?.copyWith(
              color: macros.calories,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

final class _ExerciseRecommendationSection extends StatelessWidget {
  const _ExerciseRecommendationSection({required this.recommendation});

  final DailyExerciseRecommendation recommendation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasExcess = recommendation.hasExcess;
    final hasSuggestions = recommendation.hasRecommendation;
    final accent = hasExcess ? scheme.secondary : scheme.primary;
    final title = hasSuggestions ? 'Rekomendasi Olahraga' : 'Target Harian';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasExcess
            ? scheme.secondaryContainer.withValues(alpha: 0.35)
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasExcess
              ? scheme.secondary.withValues(alpha: 0.22)
              : scheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  hasExcess
                      ? Icons.fitness_center_rounded
                      : Icons.directions_walk_rounded,
                  size: 16,
                  color: accent,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            recommendation.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
          if (hasSuggestions) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                _RecommendationChip(
                  icon: Icons.tune_rounded,
                  label: 'Level: ${recommendation.activityLevel.shortLabel}',
                  background: scheme.surfaceContainerHighest,
                  foreground: scheme.onSurfaceVariant,
                ),
                if (hasExcess)
                  _RecommendationChip(
                    icon: Icons.local_fire_department_rounded,
                    label:
                        'Target: bakar '
                        '${recommendation.targetCaloriesToBurn.round()} kkal',
                    background: scheme.secondaryContainer,
                    foreground: scheme.onSecondaryContainer,
                  )
                else
                  _RecommendationChip(
                    icon: Icons.flag_rounded,
                    label:
                        'Sisa ${recommendation.remainingCalories.round()} kkal',
                    background: scheme.primaryContainer,
                    foreground: scheme.onPrimaryContainer,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Pilih salah satu aktivitas:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...recommendation.suggestions.map(
              (ExerciseSuggestion suggestion) =>
                  _ExerciseSuggestionRow(suggestion: suggestion),
            ),
            Text(
              'Saran dipilih untuk level aktivitas '
              '${recommendation.activityLevel.shortLabel.toLowerCase()} dan berat '
              '${recommendation.weightKg.toStringAsFixed(0)} kg. Pilih salah satu; '
              'estimasi durasi dibatasi 10–90 menit dan bisa berbeda tiap orang.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

final class _ExerciseSuggestionRow extends StatelessWidget {
  const _ExerciseSuggestionRow({required this.suggestion});

  final ExerciseSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Text(suggestion.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  suggestion.name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${suggestion.intensity.label} · ${suggestion.formattedDuration} · '
                  '~${suggestion.estimatedKcalBurned} kkal',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (suggestion.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    suggestion.description,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _RecommendationChip extends StatelessWidget {
  const _RecommendationChip({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: foreground),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(color: foreground, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

final class _LocalStorageNotice extends StatelessWidget {
  const _LocalStorageNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.lock_outline_rounded, size: 15, color: scheme.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Riwayat ini tersimpan lokal di perangkat ini.',
              style: theme.textTheme.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _EmptyDiaryState extends StatelessWidget {
  const _EmptyDiaryState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 76,
                height: 76,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      scheme.primaryContainer.withValues(alpha: 0.9),
                      scheme.primaryContainer.withValues(alpha: 0.4),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.12),
                  ),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 34,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Diary masih kosong',
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Simpan hasil scan pertamamu untuk melihat total kalori dan '
                'makronutrien harian di sini.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.camera_alt_rounded, size: 20),
                label: const Text('Mulai scan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _DiaryErrorState extends StatelessWidget {
  const _DiaryErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.error.withValues(alpha: 0.16)),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 34,
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Riwayat diary belum dapat dimuat.',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Coba lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _DayGroup {
  const _DayGroup({required this.day, required this.entries});

  final DateTime day;
  final List<DiaryEntry> entries;
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<_DayGroup> _groupEntriesByDay(List<DiaryEntry> entries) {
  final byDay = <DateTime, List<DiaryEntry>>{};
  for (final entry in entries) {
    final day = DateTime(
      entry.loggedAt.year,
      entry.loggedAt.month,
      entry.loggedAt.day,
    );
    byDay.putIfAbsent(day, () => <DiaryEntry>[]).add(entry);
  }

  final days = byDay.keys.toList()
    ..sort((DateTime a, DateTime b) => b.compareTo(a));
  return <_DayGroup>[
    for (final day in days)
      _DayGroup(
        day: day,
        entries: byDay[day]!
          ..sort(
            (DiaryEntry a, DiaryEntry b) => b.loggedAt.compareTo(a.loggedAt),
          ),
      ),
  ];
}
