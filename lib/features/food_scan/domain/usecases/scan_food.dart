import 'dart:typed_data';

import '../../../../core/errors/app_exception.dart';
import '../entities/food_candidate.dart';
import '../entities/scan_result.dart';
import '../repositories/food_classifier.dart';
import '../repositories/nutrition_repository.dart';

/// Orchestrates classifier inference and nutrition enrichment.
///
/// Presentation never sees raw tensor indices or JSON; it receives a fully
/// validated [ScanResult].
final class ScanFoodUseCase {
  const ScanFoodUseCase(this._classifier, this._nutritionRepository);

  final FoodClassifier _classifier;
  final NutritionRepository _nutritionRepository;

  Future<ScanResult> call(Uint8List imageBytes, {int topK = 3}) async {
    if (imageBytes.isEmpty) {
      throw const InferenceException('Received an empty image payload.');
    }
    if (topK < 1) {
      throw ArgumentError.value(
        topK,
        'topK',
        'Must request at least one class.',
      );
    }

    await _nutritionRepository.initialize();
    await _classifier.initialize();

    final recognitions = await _classifier.classify(imageBytes, topK: topK);
    if (recognitions.isEmpty) {
      throw const InferenceException('The model returned no predictions.');
    }

    final candidates = <FoodCandidate>[];
    for (final recognition in recognitions.take(topK)) {
      final food =
          _nutritionRepository.findByIndex(recognition.classIndex) ??
          _nutritionRepository.findByLabel(recognition.label);
      if (food == null) {
        throw NutritionDataException(
          'No nutrition record for classIndex=${recognition.classIndex}, '
          'label="${recognition.label}". Regenerate nutrition_data.json.',
        );
      }
      candidates.add(
        FoodCandidate(
          food: food,
          confidence: recognition.confidence.clamp(0.0, 1.0),
        ),
      );
    }

    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return ScanResult(candidates: candidates);
  }
}
