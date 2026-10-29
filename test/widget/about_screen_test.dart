import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/core/theme/app_theme.dart';
import 'package:nutriscan/features/about/domain/entities/about_info.dart';
import 'package:nutriscan/features/about/presentation/providers/about_providers.dart';
import 'package:nutriscan/features/about/presentation/screens/about_screen.dart';
import 'package:nutriscan/features/food_scan/domain/entities/nutrition_provenance.dart';

const AboutInfo _info = AboutInfo(
  modelVersion: '2.2.0',
  modelSha256:
      'a6e0293d69d12529590fb11b0b116c7bf2739c2fd967c589a66a1857eca9c468',
  classCount: 14,
  referenceAmount: 100,
  referenceUnit: 'g',
  provenance: NutritionProvenance(
    sourceType: 'estimation',
    sourceCode: 'TKPI-2017;USDA-FDC-173292;USDA-FDC-170698;STANDARD-RECIPE',
    sourcePage: 'multiple',
    sourceUrl: 'https://repository.kemkes.go.id/book/668',
    verifiedAt: '2026-10-28',
    note: 'Nilai per 100 g adalah estimasi universal.',
  ),
  disclaimer: 'Nutrition values are estimates.',
);

Future<void> _pumpAbout(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final container = ProviderContainer(
    overrides: [aboutInfoProvider.overrideWith((ref) async => _info)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.light, home: const AboutScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows model metadata, nutrition provenance, and disclaimer', (
    tester,
  ) async {
    await _pumpAbout(tester);

    expect(find.text('Tentang NutriScan'), findsOneWidget);
    expect(find.text('Model klasifikasi'), findsOneWidget);
    expect(find.text('Batasan model'), findsOneWidget);
    expect(find.text('Sumber nilai gizi'), findsOneWidget);
    expect(find.text('Privasi & penyimpanan'), findsOneWidget);
    expect(find.text('Disclaimer'), findsOneWidget);
    expect(find.textContaining('MobileNetV3-Large'), findsOneWidget);
    expect(find.textContaining('2.2.0'), findsOneWidget);
    expect(find.text('TKPI-2017'), findsOneWidget);
    expect(find.text('USDA-FDC-173292'), findsOneWidget);
    expect(find.textContaining('2026-10-28'), findsOneWidget);
    expect(find.textContaining('bukan alat medis'), findsOneWidget);
    expect(find.textContaining('SQLite'), findsOneWidget);
    expect(
      find.textContaining('tidak memiliki kelas "tidak dikenal"'),
      findsOneWidget,
    );
    expect(find.textContaining('heuristik'), findsOneWidget);
  });
}
