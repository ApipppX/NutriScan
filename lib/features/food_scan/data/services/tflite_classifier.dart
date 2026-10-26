import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logging/app_logger.dart';
import '../../domain/entities/food_recognition.dart';
import '../../domain/repositories/food_classifier.dart';
import '../ml/inference_isolate.dart';

/// Concrete [FoodClassifier] backed by a long-lived TFLite isolate.
///
/// Model bytes and labels are loaded from Flutter assets once. The only work
/// done on the UI isolate is asset loading and message dispatch; decoding,
/// resizing, normalization, and inference happen in [InferenceWorker].
final class TfliteClassifier implements FoodClassifier {
  TfliteClassifier({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  InferenceWorker? _worker;
  List<String> _labels = const <String>[];
  Future<void>? _initializing;
  bool _initialized = false;
  bool _disposed = false;

  @override
  Future<void> initialize() {
    if (_disposed) {
      return Future<void>.error(
        const ModelInitializationException('Classifier has been disposed.'),
      );
    }
    if (_initialized && _worker != null) return Future<void>.value();
    final inFlight = _initializing;
    if (inFlight != null) return inFlight;
    final future = _initialize();
    _initializing = future;
    return future.whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    InferenceWorker? worker;
    try {
      final classNamesJson = await _bundle.loadString(AppAssets.classNames);
      final metadata = _parseMetadata(classNamesJson);
      final modelData = await _bundle.load(AppAssets.foodModel);
      final modelBytes = modelData.buffer.asUint8List(
        modelData.offsetInBytes,
        modelData.lengthInBytes,
      );

      final threads = _inferenceThreadCount();
      AppLogger.info(
        'Starting inference isolate (${modelBytes.length ~/ 1024} KiB model, '
        '${metadata.labels.length} classes, $threads threads, '
        'T=${metadata.confidenceTemperature.toStringAsFixed(3)}).',
      );

      worker = await InferenceWorker.spawn(
        modelBytes: modelBytes,
        numClasses: metadata.labels.length,
        threads: threads,
        inputSize: AppConfig.modelInputSize,
        confidenceTemperature: metadata.confidenceTemperature,
      );

      _worker = worker;
      _labels = List<String>.unmodifiable(metadata.labels);
      _initialized = true;
      AppLogger.info('TFLite model ready.');
    } on AppException {
      await worker?.dispose();
      rethrow;
    } catch (error, stackTrace) {
      await worker?.dispose();
      AppLogger.error('TFLite initialization failed.', error, stackTrace);
      throw ModelInitializationException(
        'Unable to initialise the on-device model.',
        cause: error,
      );
    }
  }

  @override
  Future<List<FoodRecognition>> classify(
    Uint8List imageBytes, {
    int topK = 3,
  }) async {
    if (_disposed) {
      throw const InferenceException('Classifier has been disposed.');
    }
    if (imageBytes.isEmpty) {
      throw const ImageDecodeException('No image data was provided.');
    }
    if (imageBytes.length > AppConfig.maxImageBytes) {
      throw const ImageDecodeException('Image is too large to process.');
    }

    await initialize();
    final worker = _worker;
    if (worker == null || _labels.isEmpty) {
      throw const InferenceException('Classifier is not ready.');
    }

    final requestedTopK = topK.clamp(1, _labels.length).toInt();
    final scores = await worker.classify(imageBytes, topK: requestedTopK);

    final results = <FoodRecognition>[];
    for (final score in scores) {
      if (score.classIndex < 0 || score.classIndex >= _labels.length) {
        throw InferenceException(
          'Model returned class index ${score.classIndex}, outside label range.',
        );
      }
      results.add(
        FoodRecognition(
          classIndex: score.classIndex,
          label: _labels[score.classIndex],
          confidence: score.confidence,
        ),
      );
    }
    return results;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _initialized = false;
    _labels = const <String>[];
    final worker = _worker;
    _worker = null;
    await worker?.dispose();
  }

  ({List<String> labels, double confidenceTemperature}) _parseMetadata(
    String rawJson,
  ) {
    try {
      final decoded = jsonDecode(rawJson);
      final rawLabels = switch (decoded) {
        {'labels': final List<dynamic> labels} => labels,
        final List<dynamic> labels => labels,
        _ => throw const FormatException('Expected a labels array.'),
      };
      final labels = <String>[];
      for (final value in rawLabels) {
        if (value is! String || value.trim().isEmpty) {
          throw const FormatException('Label must be a non-empty string.');
        }
        labels.add(value.trim());
      }
      if (labels.length < 2) {
        throw const FormatException('At least two labels are required.');
      }
      if (labels.toSet().length != labels.length) {
        throw const FormatException('Duplicate labels in class_names.json.');
      }

      var confidenceTemperature = 1.0;
      if (decoded is Map) {
        final rawTemperature = decoded['confidenceTemperature'];
        if (rawTemperature != null) {
          if (rawTemperature is! num ||
              !rawTemperature.isFinite ||
              rawTemperature <= 0.1 ||
              rawTemperature >= 10) {
            throw const FormatException(
              'confidenceTemperature must be a finite number between 0.1 and 10.',
            );
          }
          confidenceTemperature = rawTemperature.toDouble();
        }
      }
      return (labels: labels, confidenceTemperature: confidenceTemperature);
    } on AppException {
      rethrow;
    } catch (error) {
      throw ModelInitializationException(
        'class_names.json is invalid or does not match the exported model.',
        cause: error,
      );
    }
  }

  int _inferenceThreadCount() {
    // Leave headroom for the UI isolate. More than 4 threads rarely helps
    // MobileNetV3 on phones and can increase thermal throttling.
    final cores = Platform.numberOfProcessors;
    return math.max(1, math.min(4, cores - 1));
  }
}
