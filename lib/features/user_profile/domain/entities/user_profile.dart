enum Gender { male, female }

enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
  extraActive,
}

extension ActivityLevelMultiplier on ActivityLevel {
  double get multiplier => switch (this) {
    ActivityLevel.sedentary => 1.2,
    ActivityLevel.lightlyActive => 1.375,
    ActivityLevel.moderatelyActive => 1.55,
    ActivityLevel.veryActive => 1.725,
    ActivityLevel.extraActive => 1.9,
  };

  String get label => switch (this) {
    ActivityLevel.sedentary => 'Jarang olahraga (Sedenter)',
    ActivityLevel.lightlyActive => 'Olahraga ringan (1-3 hari/minggu)',
    ActivityLevel.moderatelyActive => 'Olahraga sedang (3-5 hari/minggu)',
    ActivityLevel.veryActive => 'Olahraga berat (6-7 hari/minggu)',
    ActivityLevel.extraActive => 'Sangat berat / Atlet',
  };

  /// Compact label for chips and summaries.
  String get shortLabel => switch (this) {
    ActivityLevel.sedentary => 'Sedenter',
    ActivityLevel.lightlyActive => 'Ringan',
    ActivityLevel.moderatelyActive => 'Sedang',
    ActivityLevel.veryActive => 'Berat',
    ActivityLevel.extraActive => 'Atlet',
  };

  /// One-line explanation shown next to the activity selector.
  String get description => switch (this) {
    ActivityLevel.sedentary =>
      'Sebagian besar waktu duduk; olahraga kurang dari 1x per minggu.',
    ActivityLevel.lightlyActive =>
      'Olahraga ringan 1–3 hari per minggu atau banyak berjalan.',
    ActivityLevel.moderatelyActive => 'Olahraga sedang 3–5 hari per minggu.',
    ActivityLevel.veryActive => 'Olahraga berat 6–7 hari per minggu.',
    ActivityLevel.extraActive =>
      'Latihan atlet atau pekerjaan fisik berat setiap hari.',
  };

  /// Multiplier applied to BMR, formatted for Indonesian readers.
  String get multiplierLabel => switch (this) {
    ActivityLevel.sedentary => '×1,2',
    ActivityLevel.lightlyActive => '×1,375',
    ActivityLevel.moderatelyActive => '×1,55',
    ActivityLevel.veryActive => '×1,725',
    ActivityLevel.extraActive => '×1,9',
  };
}

final class UserProfile {
  const UserProfile({
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.gender,
    required this.activityLevel,
  });

  final double weightKg;
  final double heightCm;
  final int age;
  final Gender gender;
  final ActivityLevel activityLevel;

  /// Mifflin-St Jeor Equation
  double get bmr {
    final s = gender == Gender.male ? 5 : -161;
    return (10 * weightKg) + (6.25 * heightCm) - (5 * age) + s;
  }

  /// Total Daily Energy Expenditure
  double get tdee => bmr * activityLevel.multiplier;

  static const UserProfile defaultProfile = UserProfile(
    weightKg: 70,
    heightCm: 170,
    age: 25,
    gender: Gender.male,
    activityLevel: ActivityLevel.sedentary,
  );

  UserProfile copyWith({
    double? weightKg,
    double? heightCm,
    int? age,
    Gender? gender,
    ActivityLevel? activityLevel,
  }) {
    return UserProfile(
      weightKg: weightKg ?? this.weightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
    );
  }
}
