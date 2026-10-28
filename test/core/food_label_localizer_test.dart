import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/core/localization/food_label_localizer.dart';

void main() {
  group('FoodLabelLocalizer', () {
    test('maps English snake_case labels to Indonesian names', () {
      expect(FoodLabelLocalizer.resolve('fried_noodles'), 'Olahan Mie');
      expect(FoodLabelLocalizer.resolve('fried_rice'), 'Nasi Goreng');
      expect(FoodLabelLocalizer.resolve('fried_chicken'), 'Ayam Goreng');
      expect(FoodLabelLocalizer.resolve('french_fries'), 'Kentang Goreng');
      expect(FoodLabelLocalizer.resolve('meatball_soup'), 'Bakso');
    });

    test('normalizes spacing, casing, and punctuation', () {
      expect(FoodLabelLocalizer.resolve('Fried Noodles'), 'Olahan Mie');
      expect(FoodLabelLocalizer.resolve('FRIED-NOODLES'), 'Olahan Mie');
      expect(FoodLabelLocalizer.resolve('  mie_goreng  '), 'Olahan Mie');
    });

    test('prefers the catalog display name when the key is unknown', () {
      expect(
        FoodLabelLocalizer.resolve(
          'mystery_food',
          displayName: 'Makanan Misterius',
        ),
        'Makanan Misterius',
      );
    });

    test('humanizes unknown labels as a final fallback', () {
      expect(FoodLabelLocalizer.resolve('mystery_food'), 'Mystery Food');
      expect(FoodLabelLocalizer.resolve(''), 'Makanan');
    });

    test('lookup returns null for unknown labels', () {
      expect(FoodLabelLocalizer.lookup('unknown_dish'), isNull);
      expect(FoodLabelLocalizer.lookup('fried_noodles'), 'Olahan Mie');
    });
  });
}
