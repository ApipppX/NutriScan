import '../entities/food_nutrition.dart';

/// Domain port for nutrition lookup.
///
/// Today it is backed by a bundled JSON asset. Migration to sqflite only
/// requires a new implementation of this interface, not UI changes.
abstract interface class NutritionRepository {
  Future<void> initialize();

  FoodNutrition? findByLabel(String label);

  FoodNutrition? findByIndex(int classIndex);

  List<FoodNutrition> get entries;
}
