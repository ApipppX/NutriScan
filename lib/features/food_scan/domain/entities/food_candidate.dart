import 'food_nutrition.dart';
import 'nutrition_facts.dart';

/// A ranked prediction joined with its nutrition record.
final class FoodCandidate {
  const FoodCandidate({required this.food, required this.confidence})
    : assert(confidence >= 0 && confidence <= 1);

  final FoodNutrition food;
  final double confidence;

  String get label => food.label;
  String get displayName => food.displayName;
  String get emoji => food.emoji;
  NutritionFacts get defaultPortionNutrition => food.defaultPortionNutrition;

  NutritionFacts nutritionForPortion(int grams) =>
      food.nutritionForPortion(grams);
}
