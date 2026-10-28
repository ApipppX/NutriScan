import 'dart:typed_data';

import '../../domain/entities/nutrition_facts.dart';
import '../../domain/entities/scan_result.dart';

/// Explicit UI state machine for a scan session.
sealed class ScanState {
  const ScanState();

  Uint8List? get imageBytes => null;
}

final class ScanIdle extends ScanState {
  const ScanIdle();
}

final class ScanProcessing extends ScanState {
  const ScanProcessing(this.imageBytes);

  @override
  final Uint8List imageBytes;
}

final class ScanSuccessState extends ScanState {
  const ScanSuccessState({
    required this.imageBytes,
    required this.result,
    this.portionGrams,
  });

  @override
  final Uint8List imageBytes;
  final ScanResult result;

  /// User-adjusted portion. `null` means the selected food's default portion.
  final int? portionGrams;

  int get effectivePortionGrams =>
      portionGrams ?? result.selected.food.defaultPortionGrams;

  NutritionFacts get portionNutrition =>
      result.selected.nutritionForPortion(effectivePortionGrams);

  ScanSuccessState copyWith({int? portionGrams}) => ScanSuccessState(
    imageBytes: imageBytes,
    result: result,
    portionGrams: portionGrams,
  );
}

final class ScanFailureState extends ScanState {
  const ScanFailureState({
    required this.message,
    this.imageBytes,
    this.technicalDetails,
  });

  final String message;
  final String? technicalDetails;

  @override
  final Uint8List? imageBytes;

  bool get canRetry => imageBytes != null;
}
