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
  });
}
