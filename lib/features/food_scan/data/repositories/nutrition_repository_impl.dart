import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/food_nutrition.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../datasources/nutrition_catalog_data_source.dart';

/// In-memory, O(1) nutrition lookup built from a one-time JSON read.
///
/// This is fast enough for a few hundred classes. When the catalog grows or
/// needs search/favourites, implement [NutritionRepository] with sqflite and
/// provide the same indexes; no presentation or use-case changes are needed.
final class NutritionRepositoryImpl implements NutritionRepository {
  NutritionRepositoryImpl(this._dataSource);

  final NutritionCatalogDataSource _dataSource;

  final Map<int, FoodNutrition> _byIndex = <int, FoodNutrition>{};
  final Map<String, FoodNutrition> _byLabel = <String, FoodNutrition>{};
  final List<FoodNutrition> _entries = <FoodNutrition>[];

  bool _initialized = false;
  Future<void>? _initializing;

  @override
  Future<void> initialize() {
    if (_initialized) return Future<void>.value();
    return _initializing ??= _load();
  }

  Future<void> _load() async {
    try {
      final catalog = await _dataSource.loadCatalog();
      final byIndex = <int, FoodNutrition>{};
      final byLabel = <String, FoodNutrition>{};
      final entries = <FoodNutrition>[];

      for (final entry in catalog.classes) {
        final food = entry.toDomain();
        if (byIndex.containsKey(food.classIndex)) {
          throw NutritionDataException(
            'Duplicate nutrition index ${food.classIndex}.',
          );
        }
        byIndex[food.classIndex] = food;
        entries.add(food);

        final labelKey = normalizeNutritionLabel(food.label);
        if (byLabel.containsKey(labelKey)) {
          throw NutritionDataException(
            'Duplicate nutrition label "${food.label}".',
          );
        }
        byLabel[labelKey] = food;

        for (final alias in food.aliases) {
          final aliasKey = normalizeNutritionLabel(alias);
          if (aliasKey.isEmpty) continue;
          final existing = byLabel[aliasKey];
          if (existing != null && existing.classIndex != food.classIndex) {
            throw NutritionDataException(
              'Alias "$alias" maps to both "${existing.label}" and "${food.label}".',
            );
          }
          byLabel[aliasKey] = food;
        }
      }

      if (entries.isEmpty) {
        throw const NutritionDataException('Nutrition catalog is empty.');
      }

      _byIndex
        ..clear()
        ..addAll(byIndex);
      _byLabel
        ..clear()
        ..addAll(byLabel);
      _entries
        ..clear()
        ..addAll(entries);
      _initialized = true;
    } finally {
      _initializing = null;
    }
  }

  @override
  FoodNutrition? findByIndex(int classIndex) => _byIndex[classIndex];

  @override
  FoodNutrition? findByLabel(String label) =>
      _byLabel[normalizeNutritionLabel(label)];

  @override
  List<FoodNutrition> get entries => List<FoodNutrition>.unmodifiable(_entries);
}

/// Kept identical to the Python metadata normalizer:
/// lowercase, non-alphanumeric runs -> underscore, trim underscores.
String normalizeNutritionLabel(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized;
}
