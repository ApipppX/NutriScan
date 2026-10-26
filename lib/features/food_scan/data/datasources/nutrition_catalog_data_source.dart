import 'dart:convert';

import 'package:flutter/services.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/errors/app_exception.dart';
import '../models/nutrition_catalog_model.dart';

/// Data-source boundary so the repository is independent of asset/DB details.
abstract interface class NutritionCatalogDataSource {
  Future<NutritionCatalogModel> loadCatalog();
}

/// Loads and parses the bundled nutrition JSON once per repository lifetime.
final class AssetNutritionCatalogDataSource
    implements NutritionCatalogDataSource {
  AssetNutritionCatalogDataSource({
    AssetBundle? bundle,
    this.assetPath = AppAssets.nutritionCatalog,
  }) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final String assetPath;

  @override
  Future<NutritionCatalogModel> loadCatalog() async {
    try {
      final raw = await _bundle.loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException(
          'Nutrition catalog root must be a JSON object.',
        );
      }
      return NutritionCatalogModel.fromJson(decoded);
    } on AppException {
      rethrow;
    } catch (error) {
      throw NutritionDataException('Unable to parse $assetPath.', cause: error);
    }
  }
}
