import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/features/user_profile/domain/entities/user_profile.dart';

void main() {
  test('Mifflin-St Jeor BMR and sedentary TDEE for a male', () {
    const profile = UserProfile(
      weightKg: 70,
      heightCm: 170,
      age: 25,
      gender: Gender.male,
      activityLevel: ActivityLevel.sedentary,
    );

    expect(profile.bmr, closeTo(1642.5, 1e-9));
    expect(profile.tdee, closeTo(1971, 1e-9));
  });

  test('female BMR uses the female constant and the activity multiplier', () {
    const profile = UserProfile(
      weightKg: 60,
      heightCm: 160,
      age: 30,
      gender: Gender.female,
      activityLevel: ActivityLevel.moderatelyActive,
    );

    expect(profile.bmr, closeTo(1289, 1e-9));
    expect(profile.tdee, closeTo(1997.95, 1e-9));
  });

  test('copyWith replaces only the provided fields', () {
    const profile = UserProfile(
      weightKg: 70,
      heightCm: 170,
      age: 25,
      gender: Gender.male,
      activityLevel: ActivityLevel.sedentary,
    );

    final updated = profile.copyWith(
      weightKg: 82.5,
      gender: Gender.female,
      activityLevel: ActivityLevel.veryActive,
    );

    expect(updated.weightKg, closeTo(82.5, 1e-9));
    expect(updated.heightCm, 170);
    expect(updated.age, 25);
    expect(updated.gender, Gender.female);
    expect(updated.activityLevel, ActivityLevel.veryActive);
  });

  test('every activity level exposes a distinct multiplier', () {
    final multipliers = ActivityLevel.values
        .map((ActivityLevel level) => level.multiplier)
        .toSet();

    expect(multipliers, hasLength(ActivityLevel.values.length));
    expect(ActivityLevel.sedentary.multiplier, closeTo(1.2, 1e-9));
    expect(ActivityLevel.extraActive.multiplier, closeTo(1.9, 1e-9));
  });
}
