import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/core/theme/app_theme.dart';
import 'package:nutriscan/features/food_scan/domain/entities/food_candidate.dart';
import 'package:nutriscan/features/food_scan/domain/entities/food_nutrition.dart';
import 'package:nutriscan/features/food_scan/domain/entities/nutrition_facts.dart';
import 'package:nutriscan/features/food_scan/domain/entities/scan_result.dart';
import 'package:nutriscan/features/food_scan/presentation/widgets/scan_result_card.dart';

FoodCandidate _candidate({
  required int index,
  required String label,
  required String displayName,
  required String emoji,
  required double confidence,
  required int portion,
}) {
  return FoodCandidate(
    food: FoodNutrition(
      classIndex: index,
      label: label,
      displayName: displayName,
      emoji: emoji,
      category: 'main',
      per100g: const NutritionFacts(
        caloriesKcal: 168,
        proteinG: 4.2,
        carbohydrateG: 22.4,
        fatG: 6.8,
        fiberG: 1.2,
        sodiumMg: 420,
      ),
      defaultPortionGrams: portion,
    ),
    confidence: confidence,
  );
}

void main() {
  testWidgets('result card shows nutrition and opens the portion sheet', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final result = ScanResult(
      candidates: <FoodCandidate>[
        _candidate(
          index: 4,
          label: 'nasi_goreng',
          displayName: 'Nasi Goreng',
          emoji: '🍚',
          confidence: 0.874,
          portion: 250,
        ),
        _candidate(
          index: 3,
          label: 'mie_goreng',
          displayName: 'Mie Goreng',
          emoji: '🍜',
          confidence: 0.081,
          portion: 220,
        ),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ScanResultCard(
              result: result,
              onSelectCandidate: (_) {},
              onScanAgain: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Nasi Goreng'), findsOneWidget);
    expect(find.text('420'), findsOneWidget);
    expect(find.text('87,4%'), findsOneWidget);
    expect(find.text('Protein'), findsOneWidget);
    expect(find.text('Karbo'), findsOneWidget);
    expect(find.text('Lemak'), findsOneWidget);

    final detailsButton = find.text('Atur porsi & rincian');
    await tester.ensureVisible(detailsButton);
    await tester.tap(detailsButton);
    await tester.pumpAndSettle();

    expect(find.text('Total energi'), findsOneWidget);
    expect(find.text('Atur porsi'), findsOneWidget);
    expect(find.text('250 g'), findsWidgets);
    expect(find.text('420 kkal'), findsOneWidget);

    await tester.tap(find.byTooltip('Tambah porsi'));
    await tester.pump();
    expect(find.text('260 g'), findsWidgets);

    final closeButton = find.text('Tutup');
    await tester.ensureVisible(closeButton);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();
    expect(find.text('Total energi'), findsNothing);
  });
}
