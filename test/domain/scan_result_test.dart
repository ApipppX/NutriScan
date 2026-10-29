import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/features/food_scan/domain/entities/food_candidate.dart';
import 'package:nutriscan/features/food_scan/domain/entities/food_nutrition.dart';
import 'package:nutriscan/features/food_scan/domain/entities/nutrition_facts.dart';
import 'package:nutriscan/features/food_scan/domain/entities/scan_result.dart';

FoodCandidate _candidate(String label, int index, double confidence) {
  return FoodCandidate(
    food: FoodNutrition(
      classIndex: index,
      label: label,
      displayName: label,
      emoji: '🍽️',
      per100g: const NutritionFacts(
        caloriesKcal: 100,
        proteinG: 5,
        carbohydrateG: 10,
        fatG: 4,
      ),
      defaultPortionGrams: 200,
    ),
    confidence: confidence,
  );
}

void main() {
  group('ScanResult', () {
    final candidates = <FoodCandidate>[
      _candidate('nasi_goreng', 0, 0.8),
      _candidate('mie_goreng', 1, 0.15),
      _candidate('bakso', 2, 0.05),
    ];

    test('exposes the highest-confidence candidate by default', () {
      final result = ScanResult(candidates: candidates);

      expect(result.selected.label, 'nasi_goreng');
      expect(result.hasAlternatives, isTrue);
      expect(result.alternatives.length, 2);
    });

    test('selects by index and by label', () {
      final result = ScanResult(candidates: candidates);

      expect(result.selectAt(1).selected.label, 'mie_goreng');
      expect(result.selectLabel('bakso').selectedIndex, 2);
    });

    test('keeps the candidate order after selecting an alternative', () {
      final result = ScanResult(candidates: candidates).selectAt(2);

      expect(result.candidates.map((candidate) => candidate.label), <String>[
        'nasi_goreng',
        'mie_goreng',
        'bakso',
      ]);
      expect(result.alternatives.map((candidate) => candidate.label), <String>[
        'nasi_goreng',
        'mie_goreng',
      ]);
    });

    test('rejects unknown labels and out-of-range indices', () {
      final result = ScanResult(candidates: candidates);

      expect(() => result.selectLabel('rendang'), throwsArgumentError);
      expect(() => result.selectAt(9), throwsRangeError);
    });

    test('cannot be constructed empty', () {
      expect(
        () => ScanResult(candidates: const <FoodCandidate>[]),
        throwsAssertionError,
      );
    });

    test('confidence helpers describe a clear top prediction', () {
      final result = ScanResult(candidates: candidates);

      expect(result.topConfidence, closeTo(0.8, 1e-9));
      expect(result.runnerUpConfidence, closeTo(0.15, 1e-9));
      expect(result.confidenceMargin, closeTo(0.65, 1e-9));
      expect(result.isManualSelection, isFalse);
      expect(result.isLowConfidence, isFalse);
      expect(result.isAmbiguous, isFalse);
      expect(result.needsReview, isFalse);
      expect(result.isCriticallyUncertain, isFalse);
    });

    test('manual selection is reported separately from the raw top-1', () {
      final result = ScanResult(candidates: candidates).selectAt(1);

      expect(result.isManualSelection, isTrue);
      expect(result.topConfidence, closeTo(0.8, 1e-9));
    });

    test('flags low confidence, narrow margins, and critical uncertainty', () {
      final low = ScanResult(
        candidates: <FoodCandidate>[_candidate('rendang', 0, 0.42)],
      );
      expect(low.isLowConfidence, isTrue);
      expect(low.isAmbiguous, isFalse);
      expect(low.needsReview, isTrue);
      expect(low.isCriticallyUncertain, isFalse);

      final ambiguous = ScanResult(
        candidates: <FoodCandidate>[
          _candidate('nasi_goreng', 0, 0.72),
          _candidate('mie_goreng', 1, 0.68),
        ],
      );
      expect(ambiguous.isLowConfidence, isFalse);
      expect(ambiguous.isAmbiguous, isTrue);
      expect(ambiguous.needsReview, isTrue);
      expect(ambiguous.isCriticallyUncertain, isFalse);

      final critical = ScanResult(
        candidates: <FoodCandidate>[_candidate('rendang', 0, 0.35)],
      );
      expect(critical.isLowConfidence, isTrue);
      expect(critical.needsReview, isTrue);
      expect(critical.isCriticallyUncertain, isTrue);
    });
  });
}
