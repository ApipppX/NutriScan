import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_assets.dart';
import '../../data/datasources/nutrition_catalog_data_source.dart';
import '../../data/repositories/nutrition_repository_impl.dart';
import '../../data/services/image_picker_service.dart';
import '../../data/services/tflite_classifier.dart';
import '../../domain/repositories/food_classifier.dart';
import '../../domain/repositories/nutrition_repository.dart';
import '../../domain/usecases/scan_food.dart';

final Provider<ImagePickerService> imagePickerServiceProvider =
    Provider<ImagePickerService>((ref) => ImagePickerService());

final Provider<NutritionCatalogDataSource> nutritionCatalogDataSourceProvider =
    Provider<NutritionCatalogDataSource>(
      (ref) => AssetNutritionCatalogDataSource(
        bundle: null,
        assetPath: AppAssets.nutritionCatalog,
      ),
    );

final Provider<NutritionRepository> nutritionRepositoryProvider =
    Provider<NutritionRepository>(
      (ref) => NutritionRepositoryImpl(
        ref.watch(nutritionCatalogDataSourceProvider),
      ),
    );

final Provider<FoodClassifier> foodClassifierProvider =
    Provider<FoodClassifier>((ref) {
      final classifier = TfliteClassifier();
      ref.onDispose(() => unawaited(classifier.dispose()));
      return classifier;
    });

final Provider<ScanFoodUseCase> scanFoodUseCaseProvider =
    Provider<ScanFoodUseCase>(
      (ref) => ScanFoodUseCase(
        ref.watch(foodClassifierProvider),
        ref.watch(nutritionRepositoryProvider),
      ),
    );

/// App-level warm-up gate: loads nutrition JSON and initializes the TFLite
/// interpreter before the scanner becomes interactive.
final FutureProvider<void> appBootstrapProvider = FutureProvider<void>((
  ref,
) async {
  final repository = ref.watch(nutritionRepositoryProvider);
  final classifier = ref.watch(foodClassifierProvider);
  await Future.wait<void>([repository.initialize(), classifier.initialize()]);
});
