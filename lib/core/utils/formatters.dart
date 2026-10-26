String _trimDecimal(double value, int decimals) {
  final formatted = value.toStringAsFixed(decimals);
  return formatted.replaceAll(RegExp(r'\.?0+$'), '').replaceAll('.', ',');
}

String formatKcal(double value) => '${value.round()} kkal';

String formatGrams(double value) => '${_trimDecimal(value, 1)} g';

String formatPercent(double fraction, {int decimals = 1}) {
  final clamped = fraction.clamp(0.0, 1.0);
  return '${(clamped * 100).toStringAsFixed(decimals).replaceAll('.', ',')}%';
}

String formatPortion(int grams) => '$grams g';

/// Beverages are tracked per 100 ml even though the catalog field is named
/// `defaultPortionGrams`; show the unit users expect.
String portionUnitForCategory(String category) =>
    category == 'beverage' ? 'ml' : 'g';

String formatPortionInUnit(int amount, String unit) => '$amount $unit';
