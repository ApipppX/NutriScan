import 'nutrition_facts.dart';

/// A model class mapped to one nutrition catalog entry.
final class FoodNutrition {
  const FoodNutrition({
    required this.classIndex,
    required this.label,
    required this.displayName,
    required this.emoji,
    required this.per100g,
    required this.defaultPortionGrams,
    this.category = 'main',
    this.aliases = const <String>[],
  }) : assert(classIndex >= 0),
       assert(defaultPortionGrams > 0);

  final int classIndex;
  final String label;
  final String displayName;
  final String emoji;
  final String category;
  final List<String> aliases;

  /// Values per 100 g (or 100 ml for beverages).
  final NutritionFacts per100g;

  /// Initial portion presented in the result card and detail sheet.
  final int defaultPortionGrams;

  /// Smallest portion the stepper allows.
  int get minimumPortionGrams => defaultPortionGrams <= 100 ? 25 : 50;

  /// Largest portion the stepper allows, rounded up to a friendly value.
  int get maximumPortionGrams {
    final target = (defaultPortionGrams * 2.5 / 10).ceil() * 10;
    return target < 500 ? 500 : target;
  }

  /// Keeps any user-entered amount inside the supported portion range.
  int clampPortion(int grams) =>
      grams.clamp(minimumPortionGrams, maximumPortionGrams).toInt();

  /// Grams represented by [portionCount] servings of this food.
  int gramsForPortionCount(double portionCount) =>
      (defaultPortionGrams * portionCount).round();

  /// How many default servings [grams] represents (e.g. 1.25 portions).
  double portionCountFor(int grams) => grams / defaultPortionGrams;

  NutritionFacts get defaultPortionNutrition =>
      per100g.forGrams(defaultPortionGrams.toDouble());

  NutritionFacts nutritionForPortion(int grams) =>
      per100g.forGrams(grams.toDouble());
}
