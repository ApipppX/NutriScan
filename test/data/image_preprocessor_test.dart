import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nutriscan/features/food_scan/data/ml/image_preprocessor.dart';

void main() {
  test('center-crops, resizes, converts to RGB, and normalizes to [-1, 1]', () {
    final source = img.Image(width: 4, height: 2);
    // Left half red, right half blue. A 2x2 center crop retains one column of
    // each, so the result must contain both colors in RGB order.
    for (var y = 0; y < 2; y++) {
      for (var x = 0; x < 4; x++) {
        source.setPixelRgb(x, y, x < 2 ? 255 : 0, 0, x < 2 ? 0 : 255);
      }
    }
    final bytes = Uint8List.fromList(img.encodePng(source));

    final tensor = preprocessImage(bytes, targetSize: 2);

    expect(tensor, hasLength(2 * 2 * 3));
    final values = tensor.toList();
    // Pixel (0, 0) is red; pixel (1, 0) is blue.
    expect(values.sublist(0, 3), <double>[1.0, -1.0, -1.0]);
    expect(values.sublist(3, 6), <double>[-1.0, -1.0, 1.0]);
    expect(values.every((value) => value >= -1 && value <= 1), isTrue);
  });

  test('rejects empty bytes', () {
    expect(() => preprocessImage(Uint8List(0)), throwsA(isA<Exception>()));
  });
}
