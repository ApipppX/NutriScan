import '../../../food_scan/domain/entities/nutrition_facts.dart';
import 'meal_type.dart';

/// One meal saved into the daily diary.
final class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.foodLabel,
    required this.displayName,
    required this.emoji,
    required this.mealType,
    required this.portionGrams,
    required this.portionUnit,
    required this.nutrition,
    required this.confidence,
    required this.loggedAt,
  }) : assert(portionGrams > 0),
       assert(confidence >= 0 && confidence <= 1);

  final String id;

  /// Raw class label from the model/catalog (useful for future analytics).
  final String foodLabel;

  /// Localized Indonesian name shown to the user.
  final String displayName;
  final String emoji;
  final MealType mealType;
  final int portionGrams;

  /// `g` for food, `ml` for beverages.
  final String portionUnit;

  /// Nutrition values for [portionGrams], not per 100 g.
  final NutritionFacts nutrition;
  final double confidence;
  final DateTime loggedAt;

  double get caloriesKcal => nutrition.caloriesKcal;

  bool isSameDay(DateTime other) =>
      loggedAt.year == other.year &&
      loggedAt.month == other.month &&
      loggedAt.day == other.day;
}
