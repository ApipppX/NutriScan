import '../../../user_profile/domain/entities/user_profile.dart';

/// Exercise recommendation based on daily calorie intake.
enum ExerciseIntensity {
  /// Light activity like walking, stretching.
  light,

  /// Moderate activity like jogging, cycling.
  moderate,

  /// Vigorous activity like running, HIIT.
  vigorous,
}

extension ExerciseIntensityLabel on ExerciseIntensity {
  String get label => switch (this) {
    ExerciseIntensity.light => 'Ringan',
    ExerciseIntensity.moderate => 'Sedang',
    ExerciseIntensity.vigorous => 'Berat',
  };

  String get description => switch (this) {
    ExerciseIntensity.light =>
      'Jalan kaki santai, peregangan, yoga ringan (200-300 kkal/jam)',
    ExerciseIntensity.moderate =>
      'Jogging, bersepeda santai, berenang (400-600 kkal/jam)',
    ExerciseIntensity.vigorous =>
      'Lari cepat, HIIT, basket, sepak bola (600-900+ kkal/jam)',
  };

  /// Estimated calories burned per minute for a 70 kg person.
  double get kcalPerMinute => switch (this) {
    ExerciseIntensity.light => 4.0,
    ExerciseIntensity.moderate => 8.0,
    ExerciseIntensity.vigorous => 12.0,
  };

  /// Scales the 70 kg baseline to the user's body weight.
  double kcalPerMinuteFor(double weightKg) => kcalPerMinute * weightKg / 70;
}

/// A single exercise suggestion with duration to burn target calories.
final class ExerciseSuggestion {
  const ExerciseSuggestion({
    required this.name,
    required this.intensity,
    required this.durationMinutes,
    required this.estimatedKcalBurned,
    this.emoji = '🏃',
    this.description = '',
  });

  final String name;
  final ExerciseIntensity intensity;
  final int durationMinutes;
  final int estimatedKcalBurned;
  final String emoji;

  /// Short explanation of the activity and its benefit.
  final String description;

  String get formattedDuration {
    if (durationMinutes < 60) return '$durationMinutes menit';
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    return minutes > 0 ? '$hours jam $minutes menit' : '$hours jam';
  }
}

/// Daily exercise recommendation based on total calorie intake.
final class DailyExerciseRecommendation {
  const DailyExerciseRecommendation({
    required this.totalCalories,
    required this.targetCaloriesToBurn,
    required this.suggestions,
    required this.activityLevel,
    required this.maintenanceCalories,
    this.weightKg = 70,
    this.message = '',
  });

  /// Total calories consumed today.
  final double totalCalories;

  /// Suggested calories to burn through exercise (e.g., excess over maintenance).
  final double targetCaloriesToBurn;

  /// List of exercise suggestions to meet the target.
  final List<ExerciseSuggestion> suggestions;

  /// Activity level used to pick the suggestion mix.
  final ActivityLevel activityLevel;

  /// Daily maintenance target (TDEE) used for the comparison.
  final double maintenanceCalories;

  /// Body weight used to scale the calorie-burn estimates.
  final double weightKg;

  /// Contextual message for the user.
  final String message;

  /// Whether the daily intake exceeds the maintenance target.
  bool get hasExcess => targetCaloriesToBurn > 0;

  /// Whether there is actionable exercise guidance to show.
  bool get hasRecommendation => suggestions.isNotEmpty;

  /// Calories still available before reaching the maintenance target.
  double get remainingCalories => maintenanceCalories > totalCalories
      ? maintenanceCalories - totalCalories
      : 0;

  /// Primary suggestion (first in list, matched to the activity level).
  ExerciseSuggestion? get primary =>
      suggestions.isNotEmpty ? suggestions.first : null;
}
