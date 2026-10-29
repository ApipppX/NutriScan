import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/core/theme/app_theme.dart';
import 'package:nutriscan/features/daily_diary/data/repositories/in_memory_diary_repository.dart';
import 'package:nutriscan/features/daily_diary/domain/entities/diary_entry.dart';
import 'package:nutriscan/features/daily_diary/domain/entities/meal_type.dart';
import 'package:nutriscan/features/daily_diary/presentation/providers/diary_providers.dart';
import 'package:nutriscan/features/daily_diary/presentation/screens/diary_history_screen.dart';
import 'package:nutriscan/features/food_scan/domain/entities/nutrition_facts.dart';

DiaryEntry _entry({
  required String id,
  required DateTime loggedAt,
  required MealType mealType,
  required String displayName,
  required double caloriesKcal,
  required double proteinG,
  required double carbohydrateG,
  required double fatG,
}) {
  return DiaryEntry(
    id: id,
    foodLabel: displayName.toLowerCase().replaceAll(' ', '_'),
    displayName: displayName,
    emoji: '🍽️',
    mealType: mealType,
    portionGrams: 200,
    portionUnit: 'g',
    nutrition: NutritionFacts(
      caloriesKcal: caloriesKcal,
      proteinG: proteinG,
      carbohydrateG: carbohydrateG,
      fatG: fatG,
    ),
    confidence: 0.9,
    loggedAt: loggedAt,
  );
}

Future<ProviderContainer> _pumpHistory(
  WidgetTester tester, {
  required List<DiaryEntry> entries,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final repository = InMemoryDiaryRepository();
  for (final entry in entries.reversed) {
    await repository.addEntry(entry);
  }

  final container = ProviderContainer(
    overrides: [diaryRepositoryProvider.overrideWithValue(repository)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        home: const DiaryHistoryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('groups entries by day and shows daily totals', (tester) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 12);
    final yesterday = today.subtract(const Duration(days: 1));

    await _pumpHistory(
      tester,
      entries: <DiaryEntry>[
        _entry(
          id: 'today-breakfast',
          loggedAt: today.subtract(const Duration(hours: 3)),
          mealType: MealType.breakfast,
          displayName: 'Nasi Goreng',
          caloriesKcal: 250,
          proteinG: 10,
          carbohydrateG: 30,
          fatG: 8,
        ),
        _entry(
          id: 'today-lunch',
          loggedAt: today,
          mealType: MealType.lunch,
          displayName: 'Mie Goreng',
          caloriesKcal: 100,
          proteinG: 4,
          carbohydrateG: 12,
          fatG: 4,
        ),
        _entry(
          id: 'yesterday-dinner',
          loggedAt: yesterday,
          mealType: MealType.dinner,
          displayName: 'Soto',
          caloriesKcal: 85,
          proteinG: 4.1,
          carbohydrateG: 4.6,
          fatG: 5.6,
        ),
      ],
    );

    expect(find.text('Riwayat Diary'), findsOneWidget);
    expect(find.text('Hari ini'), findsOneWidget);
    expect(find.text('Kemarin'), findsOneWidget);
    expect(find.text('2 catatan'), findsOneWidget);
    expect(find.text('1 catatan'), findsOneWidget);
    expect(find.text('Nasi Goreng'), findsOneWidget);
    expect(find.text('Mie Goreng'), findsOneWidget);
    expect(find.text('Soto'), findsOneWidget);
    expect(find.text('350 kkal'), findsOneWidget);
    expect(find.textContaining('Protein', findRichText: true), findsWidgets);
    expect(find.textContaining('14 g', findRichText: true), findsOneWidget);
    expect(find.textContaining('42 g', findRichText: true), findsOneWidget);
    expect(find.textContaining('12 g', findRichText: true), findsOneWidget);
  });

  testWidgets('shows an empty state and a scan action', (tester) async {
    await _pumpHistory(tester, entries: const <DiaryEntry>[]);

    expect(find.text('Diary masih kosong'), findsOneWidget);
    expect(find.text('Mulai scan'), findsOneWidget);
    expect(find.text('Hari ini'), findsNothing);
  });
}
