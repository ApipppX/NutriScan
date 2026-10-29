import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/features/food_scan/domain/entities/food_nutrition.dart';
import 'package:nutriscan/features/food_scan/domain/entities/nutrition_facts.dart';

void main() {
  group('FoodNutrition portion helpers', () {
    const food = FoodNutrition(
      classIndex: 0,
      label: 'mie_goreng',
      displayName: 'Mie Goreng',
      emoji: '🍜',
      per100g: NutritionFacts(
        caloriesKcal: 168,
        proteinG: 4.2,
        carbohydrateG: 22.4,
        fatG: 6.8,
      ),
      defaultPortionGrams: 250,
    );

    test('derives a safe min/max range from the default portion', () {
      expect(food.minimumPortionGrams, 50);
      expect(food.maximumPortionGrams, 630);
    });

    test('clamps user input into the supported range', () {
      expect(food.clampPortion(10), 50);
      expect(food.clampPortion(9999), 630);
      expect(food.clampPortion(300), 300);
    });

    test('converts between grams and portion counts', () {
      expect(food.gramsForPortionCount(1.5), 375);
      expect(food.portionCountFor(375), 1.5);
      expect(food.nutritionForPortion(250).caloriesKcal, closeTo(420, 1e-9));
    });

    test('uses a smaller minimum for light default portions', () {
      const beverage = FoodNutrition(
        classIndex: 1,
        label: 'es_teh',
        displayName: 'Es Teh',
        emoji: '🧋',
        category: 'beverage',
        per100g: NutritionFacts(
          caloriesKcal: 40,
          proteinG: 0,
          carbohydrateG: 10,
          fatG: 0,
        ),
        defaultPortionGrams: 100,
      );
      expect(beverage.minimumPortionGrams, 25);
      expect(beverage.maximumPortionGrams, 500);
    });
  });
}
