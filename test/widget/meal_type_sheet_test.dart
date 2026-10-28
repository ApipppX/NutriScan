import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/core/theme/app_theme.dart';
import 'package:nutriscan/features/daily_diary/domain/entities/meal_type.dart';
import 'package:nutriscan/features/daily_diary/presentation/widgets/meal_type_sheet.dart';
import 'package:nutriscan/features/food_scan/domain/entities/food_candidate.dart';
import 'package:nutriscan/features/food_scan/domain/entities/food_nutrition.dart';
import 'package:nutriscan/features/food_scan/domain/entities/nutrition_facts.dart';

const _candidate = FoodCandidate(
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
    defaultPortionGrams: 250,
  ),
  confidence: 0.9,
);

void main() {
  testWidgets('meal sheet returns the selected diary category', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    MealType? selected;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) {
              return Center(
                child: FilledButton(
                  onPressed: () async {
                    selected = await showMealTypeSheet(
                      context,
                      candidate: _candidate,
                      portionGrams: 250,
                      facts: _candidate.nutritionForPortion(250),
                    );
                  },
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Simpan ke Diary'), findsOneWidget);
    expect(find.text('Olahan Mie'), findsOneWidget);
    expect(find.text('Sarapan'), findsOneWidget);
    expect(find.text('Makan Siang'), findsOneWidget);
    expect(find.text('Makan Malam'), findsOneWidget);
    expect(find.text('Camilan'), findsOneWidget);
    expect(find.textContaining('420 kkal'), findsOneWidget);

    await tester.tap(find.text('Makan Siang'));
    await tester.pump();

    final saveButton = find.text('Simpan ke Makan Siang');
    expect(saveButton, findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(selected, MealType.lunch);
  });
}
