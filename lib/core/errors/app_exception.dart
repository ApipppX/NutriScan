/// Domain/data-layer failures with user-safe messages.
///
/// Internal details are kept in [AppException.debugMessage] for logs and never
/// rendered directly to users.
sealed class AppException implements Exception {
  const AppException(this.debugMessage, {this.cause});

  final String debugMessage;
  final Object? cause;

  @override
  String toString() => '$runtimeType: $debugMessage';
}

final class ModelInitializationException extends AppException {
  const ModelInitializationException(super.debugMessage, {super.cause});
}

final class InferenceException extends AppException {
  const InferenceException(super.debugMessage, {super.cause});
}

final class ImageDecodeException extends AppException {
  const ImageDecodeException(super.debugMessage, {super.cause});
}

final class ImagePickerException extends AppException {
  const ImagePickerException(super.debugMessage, {super.cause});
}

final class NutritionDataException extends AppException {
  const NutritionDataException(super.debugMessage, {super.cause});
}

/// A single, presentation-friendly message mapping. Keep technical details out
/// of the copy; the debug log still contains the original exception.
String userMessageFor(Object error) {
  return switch (error) {
    ModelInitializationException() =>
      'Model AI tidak dapat dimuat di perangkat ini.',
    InferenceException() => 'Analisis gambar gagal. Silakan coba lagi.',
    ImageDecodeException() => 'Gambar tidak dapat dibaca. Pilih foto lain.',
    ImagePickerException() => 'Kamera atau galeri tidak dapat dibuka.',
    NutritionDataException() => 'Data gizi untuk makanan ini belum tersedia.',
    _ => 'Terjadi kesalahan yang tidak terduga. Silakan coba lagi.',
  };
}
