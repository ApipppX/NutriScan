import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/features/daily_diary/domain/entities/meal_type.dart';
import 'package:nutriscan/features/daily_diary/presentation/providers/diary_providers.dart';
import 'package:nutriscan/features/food_scan/domain/entities/food_candidate.dart';
import 'package:nutriscan/features/food_scan/domain/entities/food_nutrition.dart';
import 'package:nutriscan/features/food_scan/domain/entities/nutrition_facts.dart';

FoodCandidate _candidate() {
  return const FoodCandidate(
    food: FoodNutrition(
      classIndex: 4,
      label: 'fried_noodles',
      displayName: 'Mie Goreng',
      emoji: '🍜',
      category: 'main',
      per100g: NutritionFacts(
        caloriesKcal: 168,
        proteinG: 4.2,
        carbohydrateG: 22.4,
        fatG: 6.8,
        fiberG: 1.2,
        sodiumMg: 420,
      ),
      defaultPortionGrams: 200,
    ),
    confidence: 0.9,
  );
}

void main() {
  test('saveMeal localizes, scales, and stores the diary entry', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(diaryControllerProvider.future);

    final entry = await container
        .read(diaryControllerProvider.notifier)
        .saveMeal(
          candidate: _candidate(),
          portionGrams: 250,
          mealType: MealType.lunch,
          confidence: 0.9,
          loggedAt: DateTime(2026, 10, 28, 12, 30),
        );

    expect(entry.displayName, 'Olahan Mie');
    expect(entry.mealType, MealType.lunch);
    expect(entry.portionGrams, 250);
    expect(entry.portionUnit, 'g');
    expect(entry.nutrition.caloriesKcal, closeTo(420, 1e-9));
    expect(entry.nutrition.proteinG, closeTo(10.5, 1e-9));
    expect(entry.nutrition.sodiumMg, closeTo(1050, 1e-9));

    final entries = container.read(diaryControllerProvider).value;
    expect(entries, hasLength(1));
    expect(entries!.single.id, entry.id);

    final controller = container.read(diaryControllerProvider.notifier);
    expect(controller.entriesForDay(DateTime(2026, 10, 28, 20)), hasLength(1));
    expect(controller.entriesForDay(DateTime(2026, 10, 29)), isEmpty);
  });

  test('saving twice keeps the newest entry first', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(diaryControllerProvider.future);
    final controller = container.read(diaryControllerProvider.notifier);

    await controller.saveMeal(
      candidate: _candidate(),
      portionGrams: 200,
      mealType: MealType.breakfast,
      confidence: 0.9,
      loggedAt: DateTime(2026, 10, 28, 7),
    );
    final latest = await controller.saveMeal(
      candidate: _candidate(),
      portionGrams: 200,
      mealType: MealType.dinner,
      confidence: 0.9,
      loggedAt: DateTime(2026, 10, 28, 19),
    );

    final entries = container.read(diaryControllerProvider).value;
    expect(entries, hasLength(2));
    expect(entries!.first.id, latest.id);
    expect(entries.first.mealType, MealType.dinner);
  });
}
