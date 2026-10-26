import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../../../../core/errors/app_exception.dart';

/// Center-crops, resizes, converts to RGB and normalizes an encoded image for
/// the exported MobileNetV3 model.
///
/// Contract: output is a flat float32 tensor for [1, size, size, 3] with values
/// in [-1, 1]. The function is pure and safe to run inside an isolate.
Float32List preprocessImage(Uint8List encodedBytes, {int targetSize = 224}) {
  if (targetSize <= 0) {
    throw ArgumentError.value(targetSize, 'targetSize', 'Must be positive.');
  }
  if (encodedBytes.isEmpty) {
    throw const ImageDecodeException('Cannot preprocess empty image bytes.');
  }

  try {
    final decoded = img.decodeImage(encodedBytes);
    if (decoded == null) {
      throw const ImageDecodeException('Unsupported or corrupt image format.');
    }
    if (decoded.width * decoded.height > 40000000) {
      throw const ImageDecodeException(
        'Image dimensions are too large to process safely.',
      );
    }

    // Bake EXIF rotation so portrait phone photos are not fed sideways.
    final oriented = img.bakeOrientation(decoded);
    final side = math.min(oriented.width, oriented.height);
    if (side <= 0) {
      throw const ImageDecodeException('Image has invalid dimensions.');
    }
    final left = (oriented.width - side) ~/ 2;
    final top = (oriented.height - side) ~/ 2;

    // Match training's crop_to_aspect_ratio=True: square center crop, then
    // resize. Using the same order avoids aspect-ratio distortion.
    final cropped = img.copyCrop(
      oriented,
      x: left,
      y: top,
      width: side,
      height: side,
    );
    final resized = img.copyResize(
      cropped,
      width: targetSize,
      height: targetSize,
      interpolation: img.Interpolation.linear,
    );

    final rgb = resized.getBytes(order: img.ChannelOrder.rgb);
    final pixelCount = targetSize * targetSize * 3;
    if (rgb.length != pixelCount) {
      throw ImageDecodeException(
        'RGB conversion returned ${rgb.length} bytes, expected $pixelCount.',
      );
    }

    final tensor = Float32List(pixelCount);
    for (var index = 0; index < pixelCount; index++) {
      tensor[index] = (rgb[index] - 127.5) / 127.5;
    }
    return tensor;
  } on AppException {
    rethrow;
  } catch (error) {
    throw ImageDecodeException('Image preprocessing failed.', cause: error);
  }
}
