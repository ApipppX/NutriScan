/// One raw classifier result before it is joined with nutrition metadata.
final class FoodRecognition {
  const FoodRecognition({
    required this.classIndex,
    required this.label,
    required this.confidence,
  }) : assert(classIndex >= 0),
       assert(confidence >= 0 && confidence <= 1);

  final int classIndex;
  final String label;
  final double confidence;
}
