/// Catalog-level provenance for the bundled nutrition values.
///
/// The app intentionally uses one universal provenance block instead of
/// pretending that every dish has an item-level citation. Individual values
/// still need recipe validation before publication.
final class NutritionProvenance {
  const NutritionProvenance({
    required this.sourceType,
    required this.sourceCode,
    required this.sourcePage,
    required this.sourceUrl,
    required this.verifiedAt,
    this.note = '',
  });

  static const String estimationSourceType = 'estimation';

  final String sourceType;
  final String sourceCode;
  final String sourcePage;
  final String sourceUrl;
  final String verifiedAt;
  final String note;

  bool get isEstimation => sourceType.toLowerCase() == estimationSourceType;

  /// Splits the compact semicolon-separated source codes for display.
  List<String> get sources => sourceCode
      .split(';')
      .map((String source) => source.trim())
      .where((String source) => source.isNotEmpty)
      .toList(growable: false);
}
