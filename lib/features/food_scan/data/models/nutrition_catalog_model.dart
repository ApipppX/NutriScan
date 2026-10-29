import '../../domain/entities/food_nutrition.dart';
import '../../domain/entities/nutrition_facts.dart';
import '../../domain/entities/nutrition_provenance.dart';

/// JSON DTOs live in the data layer so domain entities remain transport-free.
final class NutritionCatalogModel {
  const NutritionCatalogModel({
    required this.schemaVersion,
    required this.modelVersion,
    required this.classes,
    this.modelSha256,
    this.generatedAt,
    this.referenceAmount = 100,
    this.referenceUnit = 'g',
    this.disclaimer,
    this.provenance,
  });

  factory NutritionCatalogModel.fromJson(Map<String, dynamic> json) {
    final schemaVersion = _requireInt(json['schemaVersion'], 'schemaVersion');
    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported nutrition schemaVersion: $schemaVersion',
      );
    }
    final modelVersion = _requireString(json['modelVersion'], 'modelVersion');

    final provenanceRaw = json['provenance'];
    NutritionProvenanceModel? provenance;
    if (provenanceRaw != null) {
      if (provenanceRaw is! Map<String, dynamic>) {
        throw const FormatException('"provenance" must be an object.');
      }
      provenance = NutritionProvenanceModel.fromJson(provenanceRaw);
    }

    final referenceAmountRaw = json['referenceAmount'];
    final referenceAmount = referenceAmountRaw == null
        ? 100
        : _requireInt(referenceAmountRaw, 'referenceAmount');
    if (referenceAmount <= 0) {
      throw const FormatException('"referenceAmount" must be positive.');
    }
    final referenceUnitRaw = json['referenceUnit'];
    final referenceUnit =
        referenceUnitRaw is String && referenceUnitRaw.trim().isNotEmpty
        ? referenceUnitRaw.trim()
        : 'g';

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
      modelSha256: _optionalString(json['modelSha256']),
      generatedAt: _optionalString(json['generatedAt']),
      referenceAmount: referenceAmount,
      referenceUnit: referenceUnit,
      disclaimer: _optionalString(json['disclaimer']),
      provenance: provenance,
    );
  }

  final int schemaVersion;
  final String modelVersion;
  final String? modelSha256;
  final String? generatedAt;
  final int referenceAmount;
  final String referenceUnit;
  final String? disclaimer;
  final NutritionProvenanceModel? provenance;
  final List<NutritionEntryModel> classes;
}

/// Data-layer representation of the universal nutrition provenance block.
final class NutritionProvenanceModel {
  const NutritionProvenanceModel({
    required this.sourceType,
    required this.sourceCode,
    required this.sourcePage,
    required this.sourceUrl,
    required this.verifiedAt,
    this.note = '',
  });

  factory NutritionProvenanceModel.fromJson(Map<String, dynamic> json) {
    return NutritionProvenanceModel(
      sourceType: _requireString(json['sourceType'], 'sourceType'),
      sourceCode: _requireString(json['sourceCode'], 'sourceCode'),
      sourcePage: _requireString(json['sourcePage'], 'sourcePage'),
      sourceUrl: _requireString(json['sourceUrl'], 'sourceUrl'),
      verifiedAt: _requireString(json['verifiedAt'], 'verifiedAt'),
      note: _optionalString(json['note']) ?? '',
    );
  }

  final String sourceType;
  final String sourceCode;
  final String sourcePage;
  final String sourceUrl;
  final String verifiedAt;
  final String note;

  NutritionProvenance toDomain() => NutritionProvenance(
    sourceType: sourceType,
    sourceCode: sourceCode,
    sourcePage: sourcePage,
    sourceUrl: sourceUrl,
    verifiedAt: verifiedAt,
    note: note,
  );
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

String? _optionalString(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}
