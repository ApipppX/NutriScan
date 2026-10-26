import 'dart:math' as math;

/// Applies temperature scaling to a full softmax probability vector.
///
/// For softmax outputs, `softmax(logits / T)` is equivalent to
/// `p^(1/T) / sum(p^(1/T))`. The temperature is fitted on a validation split
/// by the training pipeline and stored in `class_names.json`. It changes
/// confidence values only; the predicted class and its ranking stay the same.
List<double> applyTemperatureScaling(
  List<double> probabilities,
  double temperature,
) {
  if (probabilities.isEmpty) {
    throw ArgumentError.value(
      probabilities,
      'probabilities',
      'Must not be empty.',
    );
  }
  if (!temperature.isFinite || temperature <= 0) {
    throw ArgumentError.value(
      temperature,
      'temperature',
      'Must be a positive finite number.',
    );
  }
  if (probabilities.any((value) => !value.isFinite || value < 0)) {
    throw ArgumentError.value(
      probabilities,
      'probabilities',
      'Must contain finite, non-negative values.',
    );
  }

  if ((temperature - 1.0).abs() < 1e-6) {
    return List<double>.of(probabilities);
  }

  final inverseTemperature = 1.0 / temperature;
  final scaled = List<double>.filled(probabilities.length, 0.0);
  var total = 0.0;
  for (var index = 0; index < probabilities.length; index++) {
    final value = math.pow(
      math.max(probabilities[index], 1e-12),
      inverseTemperature,
    );
    scaled[index] = value.toDouble();
    total += scaled[index];
  }
  if (!total.isFinite || total <= 0) {
    throw StateError('Could not normalise temperature-scaled probabilities.');
  }
  for (var index = 0; index < scaled.length; index++) {
    scaled[index] /= total;
  }
  return scaled;
}
