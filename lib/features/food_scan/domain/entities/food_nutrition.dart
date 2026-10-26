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

  NutritionFacts get defaultPortionNutrition =>
      per100g.forGrams(defaultPortionGrams.toDouble());

  NutritionFacts nutritionForPortion(int grams) =>
      per100g.forGrams(grams.toDouble());
}
