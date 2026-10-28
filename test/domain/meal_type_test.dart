import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/features/daily_diary/domain/entities/meal_type.dart';

void main() {
  group('MealType.forTime', () {
    test('suggests breakfast in the morning window', () {
      expect(MealType.forTime(DateTime(2026, 10, 28, 5)), MealType.breakfast);
      expect(
        MealType.forTime(DateTime(2026, 10, 28, 10, 59)),
        MealType.breakfast,
      );
    });

    test('suggests lunch around midday', () {
      expect(MealType.forTime(DateTime(2026, 10, 28, 11)), MealType.lunch);
      expect(MealType.forTime(DateTime(2026, 10, 28, 14, 59)), MealType.lunch);
    });

    test('suggests dinner in the evening window', () {
      expect(MealType.forTime(DateTime(2026, 10, 28, 17)), MealType.dinner);
      expect(MealType.forTime(DateTime(2026, 10, 28, 20, 59)), MealType.dinner);
    });

    test('falls back to snack outside meal windows', () {
      expect(MealType.forTime(DateTime(2026, 10, 28, 0)), MealType.snack);
      expect(MealType.forTime(DateTime(2026, 10, 28, 15)), MealType.snack);
      expect(MealType.forTime(DateTime(2026, 10, 28, 21)), MealType.snack);
    });
  });
}
