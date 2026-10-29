import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/features/food_scan/domain/entities/nutrition_facts.dart';

void main() {
  group('NutritionFacts', () {
    const per100g = NutritionFacts(
      caloriesKcal: 200,
      proteinG: 10,
      carbohydrateG: 20,
      fatG: 5,
      fiberG: 2,
      sodiumMg: 300,
    );

    test('scales every value for a portion', () {
      final portion = per100g.forGrams(250);

      expect(portion.caloriesKcal, closeTo(500, 1e-9));
      expect(portion.proteinG, closeTo(25, 1e-9));
      expect(portion.carbohydrateG, closeTo(50, 1e-9));
      expect(portion.fatG, closeTo(12.5, 1e-9));
      expect(portion.fiberG, closeTo(5, 1e-9));
      expect(portion.sodiumMg, closeTo(750, 1e-9));
    });

    test('computes Atwater energy shares', () {
      // Protein 40 kcal, carbs 80 kcal, fat 45 kcal -> 165 kcal total.
      expect(per100g.macroCaloriesKcal, closeTo(165, 1e-9));
      expect(
        per100g.energyShare(MacroNutrient.protein),
        closeTo(40 / 165, 1e-9),
      );
      expect(
        per100g.energyShare(MacroNutrient.carbohydrates),
        closeTo(80 / 165, 1e-9),
      );
      expect(per100g.energyShare(MacroNutrient.fat), closeTo(45 / 165, 1e-9));
    });

    test('returns zero shares when no macro energy is present', () {
      const zero = NutritionFacts(
        caloriesKcal: 0,
        proteinG: 0,
        carbohydrateG: 0,
        fatG: 0,
      );

      expect(zero.energyShare(MacroNutrient.protein), 0);
      expect(zero.energyShare(MacroNutrient.fat), 0);
    });

    test('adds portions and starts daily totals from zero', () {
      final total =
          NutritionFacts.zero + per100g.forGrams(100) + per100g.forGrams(50);

      expect(total.caloriesKcal, closeTo(300, 1e-9));
      expect(total.proteinG, closeTo(15, 1e-9));
      expect(total.carbohydrateG, closeTo(30, 1e-9));
      expect(total.fatG, closeTo(7.5, 1e-9));
      expect(total.fiberG, closeTo(3, 1e-9));
      expect(total.sodiumMg, closeTo(450, 1e-9));
    });

    test('rejects negative portions', () {
      expect(() => per100g.forGrams(-1), throwsArgumentError);
    });
  });
}
