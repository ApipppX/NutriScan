/// Meal categories used by the daily diary.
enum MealType {
  breakfast(label: 'Sarapan', windowLabel: '06.00 – 10.00'),
  lunch(label: 'Makan Siang', windowLabel: '11.00 – 14.00'),
  dinner(label: 'Makan Malam', windowLabel: '17.00 – 20.00'),
  snack(label: 'Camilan', windowLabel: 'Kapan saja');

  const MealType({required this.label, required this.windowLabel});

  final String label;
  final String windowLabel;

  /// Suggests the most likely meal category for [time].
  ///
  /// Used only as a friendly default; the user can always pick another one.
  static MealType forTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 5 && hour < 11) return MealType.breakfast;
    if (hour >= 11 && hour < 15) return MealType.lunch;
    if (hour >= 17 && hour < 21) return MealType.dinner;
    return MealType.snack;
  }
}
