import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../user_profile/domain/entities/user_profile.dart';
import '../../../user_profile/presentation/providers/user_profile_providers.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/entities/exercise_recommendation.dart';
import './diary_providers.dart';

/// Calculates daily exercise recommendation from diary entries and user profile.
final class ExerciseRecommendationController
    extends AsyncNotifier<DailyExerciseRecommendation> {
  @override
  Future<DailyExerciseRecommendation> build() async {
    final entries = await ref.watch(diaryControllerProvider.future);
    final profile = await ref.watch(userProfileProvider.future);
    return _calculateRecommendation(entries, profile);
  }

  DailyExerciseRecommendation _calculateRecommendation(
    List<DiaryEntry> entries,
    UserProfile profile,
  ) {
    final today = DateTime.now();
    final todayEntries = entries
        .where((e) => e.isSameDay(today))
        .toList(growable: false);

    final totalCalories = todayEntries.fold(
      0.0,
      (sum, e) => sum + e.caloriesKcal,
    );

    final maintenance = profile.tdee;
    final excess = totalCalories - maintenance;
    final targetToBurn = excess > 0 ? excess : 0.0;

    final suggestions = todayEntries.isEmpty
        ? const <ExerciseSuggestion>[]
        : targetToBurn > 0
        ? _buildSuggestions(
            _excessOptionsFor(profile.activityLevel),
            targetKcal: targetToBurn,
            weightKg: profile.weightKg,
          )
        : _buildSuggestions(
            _maintenanceOptionsFor(profile.activityLevel),
            targetKcal: 0,
            weightKg: profile.weightKg,
          );

    String message = '';
    if (todayEntries.isEmpty) {
      message =
          'Belum ada catatan makan hari ini. Target harianmu adalah '
          '${maintenance.toStringAsFixed(0)} kkal.';
    } else if (targetToBurn <= 0) {
      message =
          'Asupan kalori hari ini (${totalCalories.toStringAsFixed(0)} kkal) '
          'masih di bawah target harianmu (${maintenance.toStringAsFixed(0)} kkal). '
          'Tetap aktif dengan aktivitas yang sesuai levelmu untuk kesehatan.';
    } else {
      message =
          'Kamu mengonsumsi ${totalCalories.toStringAsFixed(0)} kkal hari ini. '
          'Ini melebihi target harianmu (${maintenance.toStringAsFixed(0)} kkal) '
          'sebesar ${targetToBurn.toStringAsFixed(0)} kkal. Olahraga yuk!';
    }

    return DailyExerciseRecommendation(
      totalCalories: totalCalories,
      targetCaloriesToBurn: targetToBurn,
      suggestions: suggestions,
      activityLevel: profile.activityLevel,
      maintenanceCalories: maintenance,
      weightKg: profile.weightKg,
      message: message,
    );
  }

  List<ExerciseSuggestion> _buildSuggestions(
    List<({_ExerciseOption option, int minutes})> options, {
    required double targetKcal,
    required double weightKg,
  }) {
    return <ExerciseSuggestion>[
      for (final entry in options)
        _buildSuggestion(
          entry.option,
          targetKcal: targetKcal,
          fallbackMinutes: entry.minutes,
          weightKg: weightKg,
        ),
    ];
  }

  ExerciseSuggestion _buildSuggestion(
    _ExerciseOption option, {
    required double targetKcal,
    required int fallbackMinutes,
    required double weightKg,
  }) {
    final kcalPerMinute = option.intensity.kcalPerMinuteFor(weightKg);

    var duration = fallbackMinutes;
    if (targetKcal > 0) {
      duration = (targetKcal / kcalPerMinute).ceil();
      if (duration < 10) duration = 10;
      if (duration > 90) duration = 90;
    }

    return ExerciseSuggestion(
      name: option.name,
      intensity: option.intensity,
      durationMinutes: duration,
      estimatedKcalBurned: (duration * kcalPerMinute).round(),
      emoji: option.emoji,
      description: option.description,
    );
  }
}

final AsyncNotifierProvider<
  ExerciseRecommendationController,
  DailyExerciseRecommendation
>
exerciseRecommendationProvider =
    AsyncNotifierProvider<
      ExerciseRecommendationController,
      DailyExerciseRecommendation
    >(ExerciseRecommendationController.new);

final class _ExerciseOption {
  const _ExerciseOption({
    required this.name,
    required this.intensity,
    required this.emoji,
    required this.description,
  });

  final String name;
  final ExerciseIntensity intensity;
  final String emoji;
  final String description;
}

const _walking = _ExerciseOption(
  name: 'Jalan kaki cepat',
  intensity: ExerciseIntensity.light,
  emoji: '🚶',
  description: 'Mudah dilakukan dan ramah sendi.',
);

const _walkingSantai = _ExerciseOption(
  name: 'Jalan kaki santai',
  intensity: ExerciseIntensity.light,
  emoji: '🚶',
  description: 'Aktivitas ringan untuk tetap bergerak.',
);

const _jogging = _ExerciseOption(
  name: 'Jogging santai',
  intensity: ExerciseIntensity.moderate,
  emoji: '🏃',
  description: 'Kardio dasar untuk daya tahan.',
);

const _cycling = _ExerciseOption(
  name: 'Bersepeda',
  intensity: ExerciseIntensity.moderate,
  emoji: '🚴',
  description: 'Rendah benturan, melatih kaki dan jantung.',
);

const _swimming = _ExerciseOption(
  name: 'Berenang',
  intensity: ExerciseIntensity.moderate,
  emoji: '🏊',
  description: 'Melatih seluruh tubuh tanpa beban sendi.',
);

const _running = _ExerciseOption(
  name: 'Lari (7-8 km/jam)',
  intensity: ExerciseIntensity.vigorous,
  emoji: '🏃‍♂️',
  description: 'Bakar kalori lebih cepat dan latih stamina.',
);

const _hiit = _ExerciseOption(
  name: 'HIIT / Tabata',
  intensity: ExerciseIntensity.vigorous,
  emoji: '⚡',
  description: 'Sesi singkat dengan intensitas tinggi.',
);

const _basket = _ExerciseOption(
  name: 'Basket / Futsal',
  intensity: ExerciseIntensity.vigorous,
  emoji: '🏀',
  description: 'Kardio sekaligus latihan kelincahan.',
);

const _yoga = _ExerciseOption(
  name: 'Peregangan / yoga ringan',
  intensity: ExerciseIntensity.light,
  emoji: '🧘',
  description: 'Bantu pemulihan dan kelenturan tubuh.',
);

/// Exercise mix shown when today's intake exceeds the TDEE.
List<({_ExerciseOption option, int minutes})> _excessOptionsFor(
  ActivityLevel level,
) {
  return switch (level) {
    ActivityLevel.sedentary => const [
      (option: _jogging, minutes: 20),
      (option: _cycling, minutes: 20),
      (option: _swimming, minutes: 20),
      (option: _walking, minutes: 30),
      (option: _yoga, minutes: 20),
    ],
    ActivityLevel.lightlyActive => const [
      (option: _jogging, minutes: 20),
      (option: _cycling, minutes: 20),
      (option: _swimming, minutes: 20),
      (option: _walking, minutes: 30),
      (option: _running, minutes: 20),
      (option: _hiit, minutes: 15),
    ],
    ActivityLevel.moderatelyActive => const [
      (option: _jogging, minutes: 20),
      (option: _cycling, minutes: 20),
      (option: _swimming, minutes: 20),
      (option: _walking, minutes: 30),
      (option: _running, minutes: 20),
      (option: _hiit, minutes: 15),
      (option: _basket, minutes: 20),
    ],
    ActivityLevel.veryActive => const [
      (option: _running, minutes: 25),
      (option: _hiit, minutes: 20),
      (option: _basket, minutes: 25),
      (option: _jogging, minutes: 20),
      (option: _cycling, minutes: 20),
      (option: _swimming, minutes: 20),
    ],
    ActivityLevel.extraActive => const [
      (option: _running, minutes: 30),
      (option: _hiit, minutes: 25),
      (option: _basket, minutes: 30),
      (option: _swimming, minutes: 30),
      (option: _cycling, minutes: 25),
    ],
  };
}

/// Gentle activity mix shown while today's intake is still below the TDEE.
List<({_ExerciseOption option, int minutes})> _maintenanceOptionsFor(
  ActivityLevel level,
) {
  return switch (level) {
    ActivityLevel.sedentary => const [
      (option: _walkingSantai, minutes: 30),
      (option: _yoga, minutes: 20),
      (option: _cycling, minutes: 20),
    ],
    ActivityLevel.lightlyActive => const [
      (option: _walking, minutes: 30),
      (option: _jogging, minutes: 20),
      (option: _cycling, minutes: 20),
    ],
    ActivityLevel.moderatelyActive => const [
      (option: _jogging, minutes: 30),
      (option: _cycling, minutes: 30),
      (option: _swimming, minutes: 25),
    ],
    ActivityLevel.veryActive => const [
      (option: _running, minutes: 25),
      (option: _hiit, minutes: 20),
      (option: _cycling, minutes: 30),
    ],
    ActivityLevel.extraActive => const [
      (option: _running, minutes: 30),
      (option: _hiit, minutes: 25),
      (option: _swimming, minutes: 30),
    ],
  };
}
