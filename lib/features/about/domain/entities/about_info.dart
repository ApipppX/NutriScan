import '../../../food_scan/domain/entities/nutrition_provenance.dart';

/// Read-only metadata shown on the About/sources screen.
final class AboutInfo {
  const AboutInfo({
    required this.modelVersion,
    required this.classCount,
    required this.referenceAmount,
    required this.referenceUnit,
    this.modelSha256,
    this.generatedAt,
    this.provenance,
    this.disclaimer,
  });

  final String modelVersion;
  final String? modelSha256;
  final String? generatedAt;
  final int classCount;
  final int referenceAmount;
  final String referenceUnit;
  final NutritionProvenance? provenance;
  final String? disclaimer;
}
