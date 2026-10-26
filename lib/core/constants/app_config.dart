/// Runtime constants that must stay aligned with the exported TFLite model.
abstract final class AppConfig {
  /// Model contract: float32 [1, 224, 224, 3], RGB, normalized to [-1, 1].
  static const int modelInputSize = 224;

  /// Number of ranked candidates shown in the result card.
  static const int topK = 3;

  /// Below this value the UI displays a low-confidence warning.
  static const double confidenceWarningThreshold = 0.60;

  /// Guards against a stalled native inference call.
  static const Duration inferenceTimeout = Duration(seconds: 25);

  /// Reject unexpectedly large payloads before decoding them in the isolate.
  static const int maxImageBytes = 20 * 1024 * 1024;

  /// Cap portrait-photo decoding to reduce peak memory on low-end devices.
  static const int pickerMaxDimension = 1600;
  static const int pickerImageQuality = 88;
}
