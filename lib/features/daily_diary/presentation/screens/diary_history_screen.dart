import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../food_scan/domain/entities/nutrition_facts.dart';
import '../../domain/entities/diary_entry.dart';
import '../providers/diary_providers.dart';

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

final class _DiaryHistoryList extends StatelessWidget {
  const _DiaryHistoryList({required this.entries});

  final List<DiaryEntry> entries;

  @override
  Widget build(BuildContext context) {
    final groups = _groupEntriesByDay(entries);
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
            return _DayCard(group: groups[index - 1]);
          },
        ),
      ),
    );
  }
}

final class _DayCard extends StatelessWidget {
  const _DayCard({required this.group});

  final _DayGroup group;

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
                Expanded(
                  child: Text(
                    formatDiaryDay(group.day),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${group.entries.length} catatan',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DailyTotals(facts: totals),
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
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: macros.caloriesContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
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

final class _LocalStorageNotice extends StatelessWidget {
  const _LocalStorageNotice();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: <Widget>[
        Icon(Icons.lock_outline_rounded, size: 15, color: scheme.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Riwayat ini tersimpan lokal di perangkat ini.',
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
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
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 34,
                  color: scheme.primary,
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
            Icon(Icons.error_outline_rounded, size: 44, color: scheme.error),
            const SizedBox(height: 14),
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
