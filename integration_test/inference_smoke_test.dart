import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:nutriscan/features/food_scan/data/datasources/nutrition_catalog_data_source.dart';
import 'package:nutriscan/features/food_scan/data/repositories/nutrition_repository_impl.dart';
import 'package:nutriscan/features/food_scan/data/services/tflite_classifier.dart';
import 'package:nutriscan/features/food_scan/domain/usecases/scan_food.dart';

/// Device-level smoke test: real TFLite model, real isolate, real assets.
///
/// Run with:
///   flutter test integration_test/inference_smoke_test.dart -d emulator-5554
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('loads the bundled model and completes one scan', (
    WidgetTester tester,
  ) async {
    final classifier = TfliteClassifier();
    addTearDown(classifier.dispose);

    await classifier.initialize();
    final recognitions = await classifier.classify(_syntheticImage(), topK: 3);

    expect(recognitions, hasLength(3));
    expect(
      recognitions.map((recognition) => recognition.classIndex).toSet(),
      hasLength(3),
    );
    for (final recognition in recognitions) {
      expect(recognition.label, isNotEmpty);
      expect(recognition.confidence, inInclusiveRange(0.0, 1.0));
    }

    final repository = NutritionRepositoryImpl(
      AssetNutritionCatalogDataSource(),
    );
    final useCase = ScanFoodUseCase(classifier, repository);
    final result = await useCase(_syntheticImage(), topK: 3);

    expect(result.candidates, hasLength(3));
    expect(result.selected.food.displayName, isNotEmpty);
    expect(
      result.selected.defaultPortionNutrition.caloriesKcal,
      greaterThanOrEqualTo(0),
    );
  });
}

Uint8List _syntheticImage() {
  final image = img.Image(width: 224, height: 224);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      image.setPixelRgb(
        x,
        y,
        x * 255 ~/ (image.width - 1),
        y * 255 ~/ (image.height - 1),
        120,
      );
    }
  }
  return Uint8List.fromList(img.encodeJpg(image, quality: 88));
}
