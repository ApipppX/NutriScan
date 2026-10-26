import '../../domain/entities/food_nutrition.dart';
import '../../domain/entities/nutrition_facts.dart';

/// JSON DTOs live in the data layer so domain entities remain transport-free.
final class NutritionCatalogModel {
  const NutritionCatalogModel({
    required this.schemaVersion,
    required this.modelVersion,
    required this.classes,
  });

  factory NutritionCatalogModel.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requireInt(json['schemaVersion'], 'schemaVersion');
    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported nutrition schemaVersion: $schemaVersion',
      );
    }
    final modelVersion = _requireString(json['modelVersion'], 'modelVersion');
    final rawClasses = json['classes'];
    if (rawClasses is! List || rawClasses.isEmpty) {
      throw const FormatException('"classes" must be a non-empty array.');
    }

    final classes = <NutritionEntryModel>[];
    for (var index = 0; index < rawClasses.length; index++) {
      final raw = rawClasses[index];
      if (raw is! Map<String, dynamic>) {
        throw FormatException('classes[$index] must be an object.');
      }
      classes.add(NutritionEntryModel.fromJson(raw));
    }

    final indices = <int>{};
    final labels = <String>{};
    for (final entry in classes) {
      if (!indices.add(entry.classIndex)) {
        throw FormatException('Duplicate class index ${entry.classIndex}.');
      }
      if (!labels.add(entry.label)) {
        throw FormatException('Duplicate class label "${entry.label}".');
      }
    }
    classes.sort((a, b) => a.classIndex.compareTo(b.classIndex));
    for (var index = 0; index < classes.length; index++) {
      if (classes[index].classIndex != index) {
        throw FormatException(
          'Nutrition catalog indices must be contiguous starting at 0; '
          'position $index contains index ${classes[index].classIndex}.',
        );
      }
    }

    return NutritionCatalogModel(
      schemaVersion: schemaVersion,
      modelVersion: modelVersion,
      classes: List<NutritionEntryModel>.unmodifiable(classes),
    );
  }

  final int schemaVersion;
  final String modelVersion;
  final List<NutritionEntryModel> classes;
}

final class NutritionEntryModel {
  const NutritionEntryModel({
    required this.classIndex,
    required this.label,
    required this.displayName,
    required this.emoji,
    required this.category,
    required this.defaultPortionGrams,
    required this.aliases,
    required this.per100g,
  });

  factory NutritionEntryModel.fromJson(Map<String, dynamic> json) {
    final index = _requireInt(json['index'], 'index');
    final label = _requireString(json['label'], 'label');
    final displayName = _requireString(json['displayName'], 'displayName');
    final emojiRaw = json['emoji'];
    final emoji = emojiRaw is String && emojiRaw.trim().isNotEmpty
        ? emojiRaw
        : '🍽️';
    final categoryRaw = json['category'];
    final category = categoryRaw is String && categoryRaw.isNotEmpty
        ? categoryRaw
        : 'main';

    final portion = _requireNumber(
      json['defaultPortionGrams'],
      'defaultPortionGrams',
    );
    if (portion <= 0) {
      throw FormatException(
        'defaultPortionGrams for "$label" must be positive.',
      );
    }

    final aliasesRaw = json['aliases'];
    final aliases = <String>[];
    if (aliasesRaw is List) {
      for (final alias in aliasesRaw) {
        if (alias is String && alias.trim().isNotEmpty) aliases.add(alias);
      }
    }

    final nutritionRaw = json['nutritionPer100g'];
    if (nutritionRaw is! Map<String, dynamic>) {
      throw FormatException('nutritionPer100g for "$label" must be an object.');
    }
    final per100g = NutritionFacts(
      caloriesKcal: _requireNumber(
        nutritionRaw['caloriesKcal'],
        'caloriesKcal',
      ),
      proteinG: _requireNumber(nutritionRaw['proteinG'], 'proteinG'),
      carbohydrateG: _requireNumber(
        nutritionRaw['carbohydrateG'],
        'carbohydrateG',
      ),
      fatG: _requireNumber(nutritionRaw['fatG'], 'fatG'),
      fiberG: _optionalNumber(nutritionRaw['fiberG']),
      sodiumMg: _optionalNumber(nutritionRaw['sodiumMg']),
    );

    return NutritionEntryModel(
      classIndex: index,
      label: label,
      displayName: displayName,
      emoji: emoji,
      category: category,
      defaultPortionGrams: portion.round(),
      aliases: List<String>.unmodifiable(aliases),
      per100g: per100g,
    );
  }

  final int classIndex;
  final String label;
  final String displayName;
  final String emoji;
  final String category;
  final int defaultPortionGrams;
  final List<String> aliases;
  final NutritionFacts per100g;

  FoodNutrition toDomain() => FoodNutrition(
    classIndex: classIndex,
    label: label,
    displayName: displayName,
    emoji: emoji,
    category: category,
    defaultPortionGrams: defaultPortionGrams,
    aliases: aliases,
    per100g: per100g,
  );
}

int _requireInt(Object? value, String field) {
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw FormatException('"$field" must be an integer, got $value.');
}

double _requireNumber(Object? value, String field) {
  if (value is num && value.isFinite && value >= 0) return value.toDouble();
  throw FormatException(
    '"$field" must be a finite non-negative number, got $value.',
  );
}

double _optionalNumber(Object? value) {
  if (value == null) return 0;
  if (value is num && value.isFinite && value >= 0) return value.toDouble();
  throw FormatException(
    'Optional numeric field must be finite and non-negative, got $value.',
  );
}

String _requireString(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('"$field" must be a non-empty string, got $value.');
}
