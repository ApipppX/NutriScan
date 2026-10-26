import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/features/food_scan/data/ml/probability_calibration.dart';

void main() {
  group('applyTemperatureScaling', () {
    const probabilities = <double>[0.6, 0.3, 0.1];

    test('keeps probabilities unchanged at T=1', () {
      expect(applyTemperatureScaling(probabilities, 1.0), probabilities);
    });

    test('sharpens confidence when T < 1 without changing the ranking', () {
      final calibrated = applyTemperatureScaling(probabilities, 0.5);
      expect(calibrated[0], greaterThan(probabilities[0]));
      expect(calibrated[1], lessThan(probabilities[1]));
      expect(calibrated[2], lessThan(probabilities[2]));
      expect(calibrated.reduce((a, b) => a + b), closeTo(1.0, 1e-9));
      expect(
        List<int>.generate(3, (index) => index)
          ..sort((a, b) => calibrated[b].compareTo(calibrated[a])),
        <int>[0, 1, 2],
      );
    });

    test('softens confidence when T > 1', () {
      final calibrated = applyTemperatureScaling(probabilities, 2.0);
      expect(calibrated[0], lessThan(probabilities[0]));
      expect(calibrated.reduce((a, b) => a + b), closeTo(1.0, 1e-9));
    });

    test('rejects invalid temperatures and probability vectors', () {
      expect(
        () => applyTemperatureScaling(probabilities, 0),
        throwsArgumentError,
      );
      expect(
        () => applyTemperatureScaling(probabilities, -1),
        throwsArgumentError,
      );
      expect(
        () => applyTemperatureScaling(probabilities, double.nan),
        throwsArgumentError,
      );
      expect(
        () => applyTemperatureScaling(const <double>[], 1),
        throwsArgumentError,
      );
      expect(
        () => applyTemperatureScaling(const <double>[1.1, -0.1], 1),
        throwsArgumentError,
      );
    });
  });
}
