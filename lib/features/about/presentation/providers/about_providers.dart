import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../food_scan/presentation/providers/scan_providers.dart';
import '../../domain/entities/about_info.dart';

/// Loads the catalog metadata again for the About screen.
///
/// The catalog is small and this happens only when the screen is opened. It
/// keeps provenance out of the scanner's hot path while still using the exact
/// same bundled JSON that produced the nutrition values.
final FutureProvider<AboutInfo> aboutInfoProvider = FutureProvider<AboutInfo>((
  Ref ref,
) async {
  final catalog = await ref
      .watch(nutritionCatalogDataSourceProvider)
      .loadCatalog();
  return AboutInfo(
    modelVersion: catalog.modelVersion,
    modelSha256: catalog.modelSha256,
    generatedAt: catalog.generatedAt,
    classCount: catalog.classes.length,
    referenceAmount: catalog.referenceAmount,
    referenceUnit: catalog.referenceUnit,
    provenance: catalog.provenance?.toDomain(),
    disclaimer: catalog.disclaimer,
  );
});
