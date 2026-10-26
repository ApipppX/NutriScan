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
