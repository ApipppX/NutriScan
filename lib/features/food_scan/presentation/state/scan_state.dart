import 'dart:typed_data';

import '../../domain/entities/scan_result.dart';

/// Explicit UI state machine for a scan session.
sealed class ScanState {
  const ScanState();

  Uint8List? get imageBytes => null;
}

final class ScanIdle extends ScanState {
  const ScanIdle();
}

final class ScanProcessing extends ScanState {
  const ScanProcessing(this.imageBytes);

  @override
  final Uint8List imageBytes;
}

final class ScanSuccessState extends ScanState {
  const ScanSuccessState({required this.imageBytes, required this.result});

  @override
  final Uint8List imageBytes;
  final ScanResult result;
}

final class ScanFailureState extends ScanState {
  const ScanFailureState({
    required this.message,
    this.imageBytes,
    this.technicalDetails,
  });

  final String message;
  final String? technicalDetails;

  @override
  final Uint8List? imageBytes;

  bool get canRetry => imageBytes != null;
}
