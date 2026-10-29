/// Nutrition values for a specific amount of food.
///
/// The catalog stores values per 100 g; this object can represent any portion
/// and provides energy-share calculations for the UI.
enum MacroNutrient { protein, carbohydrates, fat }

final class NutritionFacts {
  const NutritionFacts({
    required this.caloriesKcal,
    required this.proteinG,
    required this.carbohydrateG,
    required this.fatG,
    this.fiberG = 0,
    this.sodiumMg = 0,
  }) : assert(caloriesKcal >= 0),
       assert(proteinG >= 0),
       assert(carbohydrateG >= 0),
       assert(fatG >= 0),
       assert(fiberG >= 0),
       assert(sodiumMg >= 0);

  static const NutritionFacts zero = NutritionFacts(
    caloriesKcal: 0,
    proteinG: 0,
    carbohydrateG: 0,
    fatG: 0,
  );

  /// Adds the nutrient amounts of two portions.
  NutritionFacts operator +(NutritionFacts other) => NutritionFacts(
    caloriesKcal: caloriesKcal + other.caloriesKcal,
    proteinG: proteinG + other.proteinG,
    carbohydrateG: carbohydrateG + other.carbohydrateG,
    fatG: fatG + other.fatG,
    fiberG: fiberG + other.fiberG,
    sodiumMg: sodiumMg + other.sodiumMg,
  );

  final double caloriesKcal;
  final double proteinG;
  final double carbohydrateG;
  final double fatG;
  final double fiberG;
  final double sodiumMg;

  NutritionFacts forGrams(double grams) {
    if (grams < 0) {
      throw ArgumentError.value(grams, 'grams', 'Portion cannot be negative.');
    }
    return scale(grams / 100.0);
  }

  NutritionFacts scale(double factor) {
    if (factor < 0) {
      throw ArgumentError.value(factor, 'factor', 'Scale cannot be negative.');
    }
    return NutritionFacts(
      caloriesKcal: caloriesKcal * factor,
      proteinG: proteinG * factor,
      carbohydrateG: carbohydrateG * factor,
      fatG: fatG * factor,
      fiberG: fiberG * factor,
      sodiumMg: sodiumMg * factor,
    );
  }

  double get proteinCaloriesKcal => proteinG * 4;
  double get carbohydrateCaloriesKcal => carbohydrateG * 4;
  double get fatCaloriesKcal => fatG * 9;

  /// Energy from the three macronutrients (Atwater factors). Fibre is not
  /// included because it is present in very small amounts for most entries.
  double get macroCaloriesKcal =>
      proteinCaloriesKcal + carbohydrateCaloriesKcal + fatCaloriesKcal;

  /// The fraction (0..1) of macro energy contributed by [nutrient].
  double energyShare(MacroNutrient nutrient) {
    final total = macroCaloriesKcal;
    if (total <= 0) return 0;
    final calories = switch (nutrient) {
      MacroNutrient.protein => proteinCaloriesKcal,
      MacroNutrient.carbohydrates => carbohydrateCaloriesKcal,
      MacroNutrient.fat => fatCaloriesKcal,
    };
    return calories / total;
  }

  double gramsOf(MacroNutrient nutrient) => switch (nutrient) {
    MacroNutrient.protein => proteinG,
    MacroNutrient.carbohydrates => carbohydrateG,
    MacroNutrient.fat => fatG,
  };

  @override
  String toString() =>
      'NutritionFacts(kcal: $caloriesKcal, protein: $proteinG g, '
      'carbs: $carbohydrateG g, fat: $fatG g)';
}
