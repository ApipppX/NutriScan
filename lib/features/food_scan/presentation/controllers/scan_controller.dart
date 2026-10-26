import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/scan_source.dart';
import '../providers/scan_providers.dart';
import '../state/scan_state.dart';

/// Coordinates picker, use case, and UI state. No BuildContext, no widgets.
final class ScanController extends Notifier<ScanState> {
  @override
  ScanState build() => const ScanIdle();

  bool get isBusy => state is ScanProcessing;

  Future<void> pickAndScan(ScanSource source) async {
    if (isBusy) return;
    try {
      final bytes = await ref.read(imagePickerServiceProvider).pick(source);
      if (bytes == null) return; // User cancelled: preserve current screen.
      await classifyBytes(bytes);
    } on AppException catch (error, stackTrace) {
      _fail(error, stackTrace, imageBytes: null);
    } catch (error, stackTrace) {
      _fail(
        ImagePickerException('Unexpected picker failure.', cause: error),
        stackTrace,
        imageBytes: null,
      );
    }
  }

  Future<void> classifyBytes(Uint8List imageBytes) async {
    if (isBusy) return;
    if (imageBytes.isEmpty) {
      _fail(
        const ImageDecodeException('Empty image bytes.'),
        StackTrace.current,
        imageBytes: null,
      );
      return;
    }

    state = ScanProcessing(imageBytes);
    try {
      final useCase = ref.read(scanFoodUseCaseProvider);
      final result = await useCase(imageBytes, topK: AppConfig.topK);
      state = ScanSuccessState(imageBytes: imageBytes, result: result);
    } on AppException catch (error, stackTrace) {
      _fail(error, stackTrace, imageBytes: imageBytes);
    } catch (error, stackTrace) {
      _fail(
        InferenceException('Unhandled scan failure.', cause: error),
        stackTrace,
        imageBytes: imageBytes,
      );
    }
  }

  Future<void> retry() async {
    final current = state;
    if (current is! ScanFailureState) return;
    final bytes = current.imageBytes;
    if (bytes == null) return;
    await classifyBytes(bytes);
  }

  void selectCandidate(String label) {
    final current = state;
    if (current is! ScanSuccessState) return;
    try {
      state = ScanSuccessState(
        imageBytes: current.imageBytes,
        result: current.result.selectLabel(label),
      );
    } on ArgumentError catch (error, stackTrace) {
      AppLogger.error(
        'Attempted to select an unknown candidate.',
        error,
        stackTrace,
      );
    }
  }

  void reset() {
    if (isBusy) return;
    state = const ScanIdle();
  }

  void _fail(
    AppException error,
    StackTrace stackTrace, {
    required Uint8List? imageBytes,
  }) {
    AppLogger.error(error.debugMessage, error.cause ?? error, stackTrace);
    state = ScanFailureState(
      message: userMessageFor(error),
      imageBytes: imageBytes,
      technicalDetails: error.toString(),
    );
  }
}

final NotifierProvider<ScanController, ScanState> scanControllerProvider =
    NotifierProvider<ScanController, ScanState>(ScanController.new);
