import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/errors/app_exception.dart';
import 'image_preprocessor.dart';
import 'probability_calibration.dart';

/// Result of one worker inference, with no Flutter or label dependencies.
final class RawClassScore {
  const RawClassScore({required this.classIndex, required this.confidence});

  final int classIndex;
  final double confidence;
}

/// A long-lived background isolate that owns the TFLite interpreter.
///
/// Why not `Isolate.run` per scan? Loading a 3-8 MiB model, allocating tensors,
/// and warming up on every photo is wasteful. This worker is spawned once,
/// keeps the interpreter hot, and serialises jobs so the UI isolate stays at
/// 60/120 fps. Images are still copied across isolates, but preprocessing and
/// native inference both run off the UI thread.
final class InferenceWorker {
  InferenceWorker._(this._receivePort, this._errorPort, this._exitPort) {
    _receiveSub = _receivePort.listen(_handleMessage);
    _errorSub = _errorPort.listen(_handleIsolateError);
    _exitSub = _exitPort.listen((_) => _handleUnexpectedExit());
  }

  static Future<InferenceWorker> spawn({
    required Uint8List modelBytes,
    required int numClasses,
    required int threads,
    int inputSize = AppConfig.modelInputSize,
    double confidenceTemperature = 1.0,
  }) async {
    if (modelBytes.isEmpty) {
      throw const ModelInitializationException('Model asset is empty.');
    }
    if (numClasses < 2) {
      throw const ModelInitializationException(
        'Model must expose at least two classes.',
      );
    }
    if (threads < 1) {
      throw ArgumentError.value(threads, 'threads', 'Must be at least 1.');
    }
    if (!confidenceTemperature.isFinite || confidenceTemperature <= 0) {
      throw const ModelInitializationException(
        'Confidence calibration temperature must be positive and finite.',
      );
    }

    final receivePort = ReceivePort('nutriscan-inference-replies');
    final errorPort = ReceivePort('nutriscan-inference-errors');
    final exitPort = ReceivePort('nutriscan-inference-exit');
    final worker = InferenceWorker._(receivePort, errorPort, exitPort);

    try {
      worker._isolate = await Isolate.spawn(
        _inferenceWorkerMain,
        _WorkerBootstrap(
          replyPort: receivePort.sendPort,
          modelBytes: modelBytes,
          numClasses: numClasses,
          threads: threads,
          inputSize: inputSize,
          confidenceTemperature: confidenceTemperature,
        ),
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
        errorsAreFatal: true,
        debugName: 'NutriScanInference',
      );
      await worker._ready.future.timeout(const Duration(seconds: 20));
      return worker;
    } on TimeoutException {
      await worker.dispose();
      throw const ModelInitializationException(
        'Timed out while loading the TFLite model.',
      );
    } on AppException {
      await worker.dispose();
      rethrow;
    } catch (error) {
      await worker.dispose();
      throw ModelInitializationException(
        'Could not start the inference isolate.',
        cause: error,
      );
    }
  }

  final ReceivePort _receivePort;
  final ReceivePort _errorPort;
  final ReceivePort _exitPort;
  final Completer<void> _ready = Completer<void>();
  final Map<int, Completer<List<RawClassScore>>> _pending =
      <int, Completer<List<RawClassScore>>>{};

  late final StreamSubscription<Object?> _receiveSub;
  late final StreamSubscription<Object?> _errorSub;
  late final StreamSubscription<Object?> _exitSub;

  Isolate? _isolate;
  SendPort? _commandPort;
  int _nextRequestId = 0;
  bool _disposed = false;

  bool get isReady => _commandPort != null && !_disposed;

  Future<List<RawClassScore>> classify(
    Uint8List imageBytes, {
    required int topK,
  }) {
    if (_disposed) {
      return Future<List<RawClassScore>>.error(
        const InferenceException('Inference worker has been disposed.'),
      );
    }
    final commandPort = _commandPort;
    if (commandPort == null) {
      return Future<List<RawClassScore>>.error(
        const InferenceException('Inference worker is not ready.'),
      );
    }
    if (imageBytes.isEmpty) {
      return Future<List<RawClassScore>>.error(
        const ImageDecodeException('Empty image payload.'),
      );
    }

    final requestId = ++_nextRequestId;
    final completer = Completer<List<RawClassScore>>();
    _pending[requestId] = completer;
    commandPort.send(<String, Object>{
      'type': 'classify',
      'id': requestId,
      'bytes': imageBytes,
      'topK': topK,
    });

    return completer.future.timeout(
      AppConfig.inferenceTimeout,
      onTimeout: () {
        _pending.remove(requestId);
        throw const InferenceException(
          'Inference timed out. Please try again.',
        );
      },
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _commandPort?.send(<String, Object>{'type': 'dispose'});
    // Give the worker a moment to call Interpreter.close(). If it is wedged in
    // native code, kill the isolate so the app can terminate cleanly.
    await Future<void>.delayed(const Duration(milliseconds: 80));
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _commandPort = null;
    _failPending(const InferenceException('Inference worker was closed.'));
    await _receiveSub.cancel();
    await _errorSub.cancel();
    await _exitSub.cancel();
    _receivePort.close();
    _errorPort.close();
    _exitPort.close();
  }

  void _handleMessage(Object? message) {
    if (message is! Map) return;
    final type = message['type'];
    switch (type) {
      case 'ready':
        final port = message['port'];
        if (port is SendPort) {
          _commandPort = port;
          if (!_ready.isCompleted) _ready.complete();
        }
      case 'initError':
        final detail =
            message['message']?.toString() ?? 'Unknown initialization error.';
        if (!_ready.isCompleted) {
          _ready.completeError(ModelInitializationException(detail));
        }
      case 'result':
        _completeRequest(message);
      case 'error':
        _failRequest(message);
      default:
      // Ignore unknown messages for forward compatibility.
    }
  }

  void _completeRequest(Map<Object?, Object?> message) {
    final requestId = message['id'];
    if (requestId is! int) return;
    final completer = _pending.remove(requestId);
    if (completer == null || completer.isCompleted) return;

    final rawIndices = message['indices'];
    final rawScores = message['scores'];
    if (rawIndices is! List ||
        rawScores is! List ||
        rawIndices.length != rawScores.length) {
      completer.completeError(
        const InferenceException(
          'Model returned a malformed prediction payload.',
        ),
      );
      return;
    }

    try {
      final scores = <RawClassScore>[
        for (var index = 0; index < rawIndices.length; index++)
          RawClassScore(
            classIndex: (rawIndices[index] as num).toInt(),
            confidence: (rawScores[index] as num).toDouble().clamp(0.0, 1.0),
          ),
      ];
      completer.complete(scores);
    } catch (error) {
      completer.completeError(
        InferenceException(
          'Could not decode prediction payload.',
          cause: error,
        ),
      );
    }
  }

  void _failRequest(Map<Object?, Object?> message) {
    final requestId = message['id'];
    if (requestId is! int) return;
    final completer = _pending.remove(requestId);
    if (completer == null || completer.isCompleted) return;
    final detail = message['message']?.toString() ?? 'Inference failed.';
    final code = message['code'];
    if (code == 'decode') {
      completer.completeError(ImageDecodeException(detail));
    } else {
      completer.completeError(InferenceException(detail));
    }
  }

  void _handleIsolateError(Object? error) {
    final message = error is List && error.isNotEmpty
        ? error.first.toString()
        : error.toString();
    final exception = InferenceException(
      'Inference isolate crashed: $message',
      cause: error,
    );
    if (!_ready.isCompleted) _ready.completeError(exception);
    _failPending(exception);
  }

  void _handleUnexpectedExit() {
    if (_disposed) return;
    final exception = const ModelInitializationException(
      'Inference isolate exited unexpectedly.',
    );
    if (!_ready.isCompleted) _ready.completeError(exception);
    _failPending(exception);
  }

  void _failPending(AppException error) {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
  }
}

final class _WorkerBootstrap {
  const _WorkerBootstrap({
    required this.replyPort,
    required this.modelBytes,
    required this.numClasses,
    required this.threads,
    required this.inputSize,
    required this.confidenceTemperature,
  });

  final SendPort replyPort;
  final Uint8List modelBytes;
  final int numClasses;
  final int threads;
  final int inputSize;
  final double confidenceTemperature;
}

@pragma('vm:entry-point')
void _inferenceWorkerMain(_WorkerBootstrap bootstrap) {
  final commandPort = ReceivePort('nutriscan-inference-commands');
  Interpreter? interpreter;
  try {
    final options = InterpreterOptions()..threads = bootstrap.threads;
    interpreter = Interpreter.fromBuffer(
      bootstrap.modelBytes,
      options: options,
    );

    final inputTensor = interpreter.getInputTensor(0);
    final outputTensor = interpreter.getOutputTensor(0);
    final inputShape = inputTensor.shape;
    final expectedPixels = bootstrap.inputSize * bootstrap.inputSize * 3;
    if (inputTensor.type != TensorType.float32) {
      throw StateError(
        'Expected float32 model input, got ${inputTensor.type}.',
      );
    }
    if (outputTensor.type != TensorType.float32) {
      throw StateError(
        'Expected float32 model output, got ${outputTensor.type}.',
      );
    }
    if (inputShape.length != 4 ||
        inputShape[0] != 1 ||
        inputShape[1] != bootstrap.inputSize ||
        inputShape[2] != bootstrap.inputSize ||
        inputShape[3] != 3) {
      throw StateError(
        'Expected input [1, ${bootstrap.inputSize}, ${bootstrap.inputSize}, 3], got $inputShape.',
      );
    }
    if (inputTensor.numElements() != expectedPixels) {
      throw StateError(
        'Input tensor has ${inputTensor.numElements()} elements, expected $expectedPixels.',
      );
    }
    if (outputTensor.numElements() != bootstrap.numClasses) {
      throw StateError(
        'Model outputs ${outputTensor.numElements()} classes, but class_names.json '
        'contains ${bootstrap.numClasses}.',
      );
    }

    // Allocate working buffers once, not per scan. The native interpreter is
    // reused for every request.
    final warmupInput = Uint8List(inputTensor.numBytes());
    final outputBytes = Uint8List(outputTensor.numBytes());
    inputTensor.setTo(warmupInput);
    interpreter.invoke();
    outputTensor.copyTo(outputBytes);
    _probabilitiesFromOutput(
      outputBytes,
      bootstrap.numClasses,
    ); // contract probe

    bootstrap.replyPort.send(<String, Object>{
      'type': 'ready',
      'port': commandPort.sendPort,
      'inputShape': inputShape,
    });
  } catch (error) {
    bootstrap.replyPort.send(<String, Object>{
      'type': 'initError',
      'message': error.toString(),
    });
    interpreter?.close();
    commandPort.close();
    return;
  }

  commandPort.listen((message) {
    if (message is! Map) return;
    if (message['type'] == 'dispose') {
      interpreter?.close();
      commandPort.close();
      Isolate.current.kill(priority: Isolate.immediate);
      return;
    }
    if (message['type'] != 'classify') return;

    final requestId = message['id'];
    if (requestId is! int) return;
    final rawBytes = message['bytes'];
    final rawTopK = message['topK'];
    if (rawBytes is! Uint8List) {
      bootstrap.replyPort.send(<String, Object>{
        'type': 'error',
        'id': requestId,
        'code': 'decode',
        'message': 'Image payload is not a byte buffer.',
      });
      return;
    }

    try {
      final topK = rawTopK is num
          ? rawTopK.toInt().clamp(1, bootstrap.numClasses).toInt()
          : 3;
      final input = preprocessImage(rawBytes, targetSize: bootstrap.inputSize);

      final inputTensor = interpreter!.getInputTensor(0);
      final outputTensor = interpreter.getOutputTensor(0);
      if (input.length * 4 != inputTensor.numBytes()) {
        throw StateError(
          'Preprocessed tensor mismatch: ${input.length} floats vs '
          '${inputTensor.numBytes()} bytes.',
        );
      }

      // Pass raw bytes directly: tflite_flutter's recursive list converter
      // would otherwise iterate 150,528 floats and be dramatically slower.
      inputTensor.setTo(
        input.buffer.asUint8List(input.offsetInBytes, input.lengthInBytes),
      );
      interpreter.invoke();

      final copiedOutput = outputTensor.copyTo(
        Uint8List(outputTensor.numBytes()),
      );
      if (copiedOutput is! Uint8List) {
        throw StateError('Unexpected TFLite output buffer type.');
      }
      final rawProbabilities = _probabilitiesFromOutput(
        copiedOutput,
        bootstrap.numClasses,
      );
      final probabilities = applyTemperatureScaling(
        rawProbabilities,
        bootstrap.confidenceTemperature,
      );

      final rankedIndices = List<int>.generate(
        bootstrap.numClasses,
        (index) => index,
      )..sort((a, b) => probabilities[b].compareTo(probabilities[a]));
      final selected = rankedIndices.take(topK).toList(growable: false);

      bootstrap.replyPort.send(<String, Object>{
        'type': 'result',
        'id': requestId,
        'indices': selected,
        'scores': <double>[for (final index in selected) probabilities[index]],
      });
    } catch (error) {
      final isDecodeError = error is ImageDecodeException;
      final messageType = message['type'];
      if (messageType == 'classify') {
        bootstrap.replyPort.send(<String, Object>{
          'type': 'error',
          'id': requestId,
          'code': isDecodeError ? 'decode' : 'inference',
          'message': error.toString(),
        });
      }
    }
  });
}

/// Copies a [1, numClasses] float32 output into a plain Dart list and applies a
/// stable softmax fallback for models exported with logits.
List<double> _probabilitiesFromOutput(Uint8List outputBytes, int numClasses) {
  if (outputBytes.length != numClasses * 4) {
    throw StateError(
      'Output payload has ${outputBytes.length} bytes, expected ${numClasses * 4}.',
    );
  }
  final view = outputBytes.buffer.asFloat32List(
    outputBytes.offsetInBytes,
    numClasses,
  );
  final probabilities = List<double>.generate(
    numClasses,
    (index) => view[index],
  );
  if (probabilities.any((value) => !value.isFinite)) {
    throw StateError('Model output contains NaN or infinite values.');
  }

  final sum = probabilities.fold<double>(0, (total, value) => total + value);
  final looksLikeProbabilities =
      probabilities.every((value) => value >= -0.0001 && value <= 1.0001) &&
      (sum - 1.0).abs() <= 0.05;
  if (looksLikeProbabilities) return probabilities;

  final maxValue = probabilities.reduce(math.max);
  var expSum = 0.0;
  for (var index = 0; index < probabilities.length; index++) {
    final expValue = math.exp(probabilities[index] - maxValue);
    probabilities[index] = expValue;
    expSum += expValue;
  }
  if (expSum == 0 || !expSum.isFinite) {
    throw StateError('Could not normalise model output.');
  }
  for (var index = 0; index < probabilities.length; index++) {
    probabilities[index] /= expSum;
  }
  return probabilities;
}
