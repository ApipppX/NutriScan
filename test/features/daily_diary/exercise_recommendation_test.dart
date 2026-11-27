import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/features/daily_diary/data/repositories/in_memory_diary_repository.dart';
import 'package:nutriscan/features/daily_diary/domain/entities/diary_entry.dart';
import 'package:nutriscan/features/daily_diary/domain/entities/exercise_recommendation.dart';
import 'package:nutriscan/features/daily_diary/domain/entities/meal_type.dart';
import 'package:nutriscan/features/daily_diary/presentation/providers/diary_providers.dart';
import 'package:nutriscan/features/daily_diary/presentation/providers/exercise_providers.dart';
import 'package:nutriscan/features/food_scan/domain/entities/nutrition_facts.dart';
import 'package:nutriscan/features/user_profile/data/repositories/in_memory_user_profile_repository.dart';
import 'package:nutriscan/features/user_profile/domain/entities/user_profile.dart';
import 'package:nutriscan/features/user_profile/presentation/providers/user_profile_providers.dart';

DiaryEntry _entry({required String id, required double caloriesKcal}) {
  return DiaryEntry(
    id: id,
    foodLabel: 'nasi_goreng',
    displayName: 'Nasi Goreng',
    emoji: '🍛',
    mealType: MealType.lunch,
    portionGrams: 250,
    portionUnit: 'g',
    nutrition: NutritionFacts(
      caloriesKcal: caloriesKcal,
      proteinG: 10,
      carbohydrateG: 30,
      fatG: 8,
    ),
    confidence: 0.9,
    loggedAt: DateTime.now(),
  );
}

Future<DailyExerciseRecommendation> _recommendation({
  required List<DiaryEntry> entries,
  UserProfile? profile,
}) async {
  final diaryRepository = InMemoryDiaryRepository();
  for (final entry in entries.reversed) {
    await diaryRepository.addEntry(entry);
  }
  final profileRepository = InMemoryUserProfileRepository(
    initialProfile: profile,
  );
  final container = ProviderContainer(
    overrides: [
      diaryRepositoryProvider.overrideWithValue(diaryRepository),
      userProfileRepositoryProvider.overrideWithValue(profileRepository),
    ],
  );
  addTearDown(container.dispose);

  return container.read(exerciseRecommendationProvider.future);
}

void main() {
  test('explains the daily target when the diary is empty', () async {
    final recommendation = await _recommendation(entries: const <DiaryEntry>[]);

    expect(recommendation.totalCalories, 0);
    expect(recommendation.targetCaloriesToBurn, 0);
    expect(recommendation.suggestions, isEmpty);
    expect(recommendation.hasRecommendation, isFalse);
    expect(recommendation.activityLevel, ActivityLevel.sedentary);
    expect(recommendation.maintenanceCalories, closeTo(1971, 1e-9));
    expect(recommendation.message, contains('Belum ada catatan makan'));
    expect(recommendation.message, contains('1971 kkal'));
  });

  test('suggests light activity while intake is below the TDEE', () async {
    final recommendation = await _recommendation(
      entries: <DiaryEntry>[
        _entry(id: 'lunch', caloriesKcal: 500),
        _entry(id: 'dinner', caloriesKcal: 700),
      ],
    );

    expect(recommendation.totalCalories, closeTo(1200, 1e-9));
    expect(recommendation.targetCaloriesToBurn, 0);
    expect(recommendation.hasExcess, isFalse);
    expect(recommendation.hasRecommendation, isTrue);
    expect(recommendation.activityLevel, ActivityLevel.sedentary);
    expect(recommendation.remainingCalories, closeTo(771, 1e-9));
    expect(recommendation.suggestions, hasLength(3));
    expect(
      recommendation.suggestions.map((s) => s.name),
      containsAll(<String>[
        'Jalan kaki santai',
        'Peregangan / yoga ringan',
        'Bersepeda',
      ]),
    );
    expect(
      recommendation.suggestions.every((s) => s.description.isNotEmpty),
      isTrue,
    );
    expect(recommendation.message, contains('masih di bawah target'));
    expect(recommendation.message, contains('Tetap aktif'));
  });

  test('suggests exercises that burn the excess over the TDEE', () async {
    final recommendation = await _recommendation(
      entries: <DiaryEntry>[_entry(id: 'big-meal', caloriesKcal: 2471)],
    );

    expect(recommendation.totalCalories, closeTo(2471, 1e-9));
    expect(recommendation.targetCaloriesToBurn, closeTo(500, 1e-9));
    expect(recommendation.hasRecommendation, isTrue);
    expect(recommendation.hasExcess, isTrue);
    expect(recommendation.suggestions, hasLength(5));

    final primary = recommendation.primary;
    expect(primary, isNotNull);
    expect(primary!.intensity, ExerciseIntensity.moderate);
    expect(primary.durationMinutes, 63);
    expect(primary.estimatedKcalBurned, 504);
    expect(primary.description, isNotEmpty);
    expect(recommendation.message, contains('melebihi target harianmu'));
  });

  test('tailors excess suggestions to the activity level', () async {
    const athlete = UserProfile(
      weightKg: 70,
      heightCm: 170,
      age: 25,
      gender: Gender.male,
      activityLevel: ActivityLevel.extraActive,
    );

    final recommendation = await _recommendation(
      entries: <DiaryEntry>[_entry(id: 'big-meal', caloriesKcal: 4000)],
      profile: athlete,
    );

    expect(recommendation.activityLevel, ActivityLevel.extraActive);
    expect(recommendation.hasExcess, isTrue);
    expect(recommendation.primary, isNotNull);
    expect(recommendation.primary!.intensity, ExerciseIntensity.vigorous);
    expect(
      recommendation.suggestions.map((s) => s.name),
      contains('HIIT / Tabata'),
    );
    expect(
      recommendation.suggestions.map((s) => s.name),
      isNot(contains('Jalan kaki cepat')),
    );
  });

  test('offers maintenance activities that match the activity level', () async {
    const athlete = UserProfile(
      weightKg: 70,
      heightCm: 170,
      age: 25,
      gender: Gender.male,
      activityLevel: ActivityLevel.extraActive,
    );

    final recommendation = await _recommendation(
      entries: <DiaryEntry>[_entry(id: 'snack', caloriesKcal: 500)],
      profile: athlete,
    );

    expect(recommendation.hasExcess, isFalse);
    expect(
      recommendation.suggestions.map((s) => s.name),
      contains('HIIT / Tabata'),
    );
    expect(
      recommendation.suggestions.map((s) => s.name),
      isNot(contains('Jalan kaki santai')),
    );
  });

  test('caps a suggestion at 90 minutes and never goes below 10', () async {
    final longSession = await _recommendation(
      entries: <DiaryEntry>[_entry(id: 'feast', caloriesKcal: 6000)],
    );
    final shortSession = await _recommendation(
      entries: <DiaryEntry>[_entry(id: 'snack', caloriesKcal: 1981)],
    );

    expect(
      longSession.suggestions.map((s) => s.durationMinutes),
      everyElement(90),
    );
    expect(
      shortSession.suggestions.map((s) => s.durationMinutes),
      everyElement(10),
    );
  });

  test('scales burn estimates with the profile weight', () async {
    final recommendation = await _recommendation(
      entries: <DiaryEntry>[_entry(id: 'lunch', caloriesKcal: 3000)],
      profile: const UserProfile(
        weightKg: 100,
        heightCm: 180,
        age: 30,
        gender: Gender.male,
        activityLevel: ActivityLevel.sedentary,
      ),
    );

    expect(recommendation.weightKg, closeTo(100, 1e-9));
    expect(recommendation.targetCaloriesToBurn, closeTo(624, 1e-9));
    expect(recommendation.primary, isNotNull);
    expect(recommendation.primary!.intensity, ExerciseIntensity.moderate);
    expect(recommendation.primary!.durationMinutes, 55);
    expect(recommendation.primary!.estimatedKcalBurned, 629);
  });
}
