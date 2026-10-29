import '../../../../core/constants/app_config.dart';
import 'food_candidate.dart';

/// Immutable result of one scan, including ranked alternatives.
final class ScanResult {
  ScanResult({required List<FoodCandidate> candidates, this.selectedIndex = 0})
    : assert(candidates.isNotEmpty),
      assert(selectedIndex >= 0 && selectedIndex < candidates.length),
      candidates = List<FoodCandidate>.unmodifiable(candidates);

  final List<FoodCandidate> candidates;
  final int selectedIndex;

  FoodCandidate get selected => candidates[selectedIndex];
  bool get hasAlternatives => candidates.length > 1;

  /// Confidence of the model's top prediction.
  double get topConfidence => candidates.first.confidence;

  /// Confidence of the second-ranked prediction, or zero when absent.
  double get runnerUpConfidence =>
      candidates.length > 1 ? candidates[1].confidence : 0;

  /// Gap between the top two predictions. A narrow gap means the model is
  /// torn between classes even when the top score looks acceptable.
  double get confidenceMargin =>
      (topConfidence - runnerUpConfidence).clamp(0.0, 1.0);

  /// True when the user explicitly picked a non-top candidate.
  bool get isManualSelection => selectedIndex != 0;

  bool get isLowConfidence =>
      topConfidence < AppConfig.confidenceWarningThreshold;

  bool get isAmbiguous =>
      candidates.length > 1 &&
      confidenceMargin < AppConfig.confidenceMarginThreshold;

  /// The result should be reviewed or retaken before it is trusted.
  bool get needsReview => isLowConfidence || isAmbiguous;

  /// Review requirement for the currently displayed candidate. The top-1
  /// heuristics do not cover a manually selected low-confidence alternative.
  bool get selectedNeedsReview =>
      needsReview || selected.confidence < AppConfig.confidenceWarningThreshold;

  /// Very low confidence: the photo may not contain a supported food at all.
  bool get isCriticallyUncertain =>
      topConfidence < AppConfig.confidenceCriticalThreshold;

  /// Alternatives excluding the currently selected candidate.
  List<FoodCandidate> get alternatives => List<FoodCandidate>.unmodifiable(
    candidates.where((candidate) => candidate != selected),
  );

  ScanResult selectAt(int index) {
    if (index < 0 || index >= candidates.length) {
      throw RangeError.index(index, candidates);
    }
    return ScanResult(candidates: candidates, selectedIndex: index);
  }

  ScanResult selectLabel(String label) {
    final index = candidates.indexWhere(
      (candidate) => candidate.label == label,
    );
    if (index < 0) {
      throw ArgumentError.value(label, 'label', 'Not part of this result.');
    }
    return selectAt(index);
  }
}
