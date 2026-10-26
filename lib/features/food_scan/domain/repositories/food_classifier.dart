import 'dart:typed_data';

import '../entities/food_recognition.dart';

/// Domain port for the on-device classifier.
///
/// Implementations are responsible for running preprocessing and TFLite
/// inference away from the UI isolate.
abstract interface class FoodClassifier {
  Future<void> initialize();

  Future<List<FoodRecognition>> classify(Uint8List imageBytes, {int topK = 3});

  Future<void> dispose();
}
