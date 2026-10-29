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

Widget _host({
  required ScanResult result,
  required int portionGrams,
  required ValueChanged<int> onPortionChanged,
  required VoidCallback onRetake,
  required ValueChanged<String> onSelectCandidate,
  required VoidCallback onScanAgain,
}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ScanResultCard(
          result: result,
          portionGrams: portionGrams,
          supportedFoods: result.candidates
              .map((FoodCandidate candidate) => candidate.food)
              .toList(growable: false),
          onSelectCandidate: onSelectCandidate,
          onPortionChanged: onPortionChanged,
          onRetake: onRetake,
          onScanAgain: onScanAgain,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('result card localizes the label and shows complete nutrition', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var portionGrams = 250;
    final result = ScanResult(
      candidates: <FoodCandidate>[
        _candidate(
          index: 4,
          label: 'fried_noodles',
          displayName: 'Mie Goreng',
          emoji: '🍜',
          confidence: 0.874,
          portion: 250,
        ),
        _candidate(
          index: 3,
          label: 'nasi_goreng',
          displayName: 'Nasi Goreng',
          emoji: '🍚',
          confidence: 0.081,
          portion: 220,
        ),
      ],
    );

    await tester.pumpWidget(
      _host(
        result: result,
        portionGrams: portionGrams,
        onPortionChanged: (value) => portionGrams = value,
        onRetake: () {},
        onSelectCandidate: (_) {},
        onScanAgain: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Olahan Mie'), findsOneWidget);
    expect(find.text('87,4%'), findsOneWidget);
    expect(find.text('Keyakinan AI'), findsOneWidget);
    expect(find.text('Energi'), findsOneWidget);
    expect(find.text('Protein'), findsWidgets);
    expect(find.text('Karbohidrat'), findsWidgets);
    expect(find.text('Lemak'), findsWidgets);
    expect(find.text('Serat'), findsOneWidget);
    expect(find.text('Natrium'), findsOneWidget);
    expect(find.text('PER PORSI'), findsOneWidget);
    expect(find.text('PER 100 G'), findsOneWidget);
    expect(find.text('420 kkal'), findsOneWidget);
    expect(find.text('168 kkal'), findsOneWidget);
    expect(find.text('1.050 mg'), findsOneWidget);
    expect(find.text('420 mg'), findsOneWidget);
    expect(find.text('Lihat 2 makanan yang didukung'), findsOneWidget);

    final detailsButton = find.text('Rincian lengkap');
    await tester.ensureVisible(detailsButton);
    await tester.tap(detailsButton);
    await tester.pumpAndSettle();

    expect(find.text('Total energi'), findsOneWidget);
    expect(find.text('Distribusi energi'), findsOneWidget);
    expect(find.text('Rincian zat gizi'), findsOneWidget);
    expect(find.text('PER 100 G'), findsWidgets);
    expect(find.text('Natrium'), findsWidgets);

    final closeButton = find.text('Tutup');
    await tester.ensureVisible(closeButton);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();
    expect(find.text('Total energi'), findsNothing);
  });

  testWidgets('portion stepper recalculates calories dynamically', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var portionGrams = 250;
    final result = ScanResult(
      candidates: <FoodCandidate>[
        _candidate(
          index: 4,
          label: 'mie_goreng',
          displayName: 'Mie Goreng',
          emoji: '🍜',
          confidence: 0.874,
          portion: 250,
        ),
      ],
    );

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return _host(
            result: result,
            portionGrams: portionGrams,
            onPortionChanged: (value) => setState(() => portionGrams = value),
            onRetake: () {},
            onSelectCandidate: (_) {},
            onScanAgain: () {},
          );
        },
      ),
    );
    await tester.pumpAndSettle();

    final addButton = find.byTooltip('Tambah porsi');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('260 g'), findsWidgets);
    expect(find.text('437 kkal'), findsOneWidget);
    expect(find.text('437'), findsOneWidget);
  });

  testWidgets('low confidence reveals the review and supported-food actions', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var retook = false;
    final result = ScanResult(
      candidates: <FoodCandidate>[
        _candidate(
          index: 4,
          label: 'mie_goreng',
          displayName: 'Mie Goreng',
          emoji: '🍜',
          confidence: 0.42,
          portion: 250,
        ),
        _candidate(
          index: 3,
          label: 'nasi_goreng',
          displayName: 'Nasi Goreng',
          emoji: '🍚',
          confidence: 0.30,
          portion: 220,
        ),
      ],
    );

    await tester.pumpWidget(
      _host(
        result: result,
        portionGrams: 250,
        onPortionChanged: (_) {},
        onRetake: () => retook = true,
        onSelectCandidate: (_) {},
        onScanAgain: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Rendah'), findsOneWidget);
    expect(find.text('Hasil perlu diperiksa'), findsOneWidget);

    final supportedFoodsButton = find.text('Daftar makanan');
    expect(supportedFoodsButton, findsOneWidget);
    await tester.ensureVisible(supportedFoodsButton);
    await tester.tap(supportedFoodsButton);
    await tester.pumpAndSettle();

    expect(find.text('Makanan yang didukung'), findsOneWidget);
    expect(find.text('2 kelas dalam model ini'), findsOneWidget);
    expect(
      find.textContaining('memiliki kelas "tidak dikenal"'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Tutup'));
    await tester.pumpAndSettle();

    final retakeButton = find.text('Foto Ulang');
    expect(retakeButton, findsOneWidget);
    await tester.ensureVisible(retakeButton);
    await tester.tap(retakeButton);
    await tester.pump();

    expect(retook, isTrue);
  });

  testWidgets(
    'critically uncertain result warns that food may be unsupported',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final result = ScanResult(
        candidates: <FoodCandidate>[
          _candidate(
            index: 4,
            label: 'mie_goreng',
            displayName: 'Mie Goreng',
            emoji: '🍜',
            confidence: 0.35,
            portion: 250,
          ),
        ],
      );

      await tester.pumpWidget(
        _host(
          result: result,
          portionGrams: 250,
          onPortionChanged: (_) {},
          onRetake: () {},
          onSelectCandidate: (_) {},
          onScanAgain: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sangat rendah'), findsOneWidget);
      expect(find.text('Makanan mungkin tidak dikenali'), findsOneWidget);
      expect(
        find.textContaining('bukan salah satu makanan yang didukung'),
        findsOneWidget,
      );
    },
  );

  testWidgets('narrow top-two margin is flagged even above the low threshold', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final result = ScanResult(
      candidates: <FoodCandidate>[
        _candidate(
          index: 4,
          label: 'mie_goreng',
          displayName: 'Mie Goreng',
          emoji: '🍜',
          confidence: 0.72,
          portion: 250,
        ),
        _candidate(
          index: 3,
          label: 'nasi_goreng',
          displayName: 'Nasi Goreng',
          emoji: '🍚',
          confidence: 0.68,
          portion: 220,
        ),
      ],
    );

    await tester.pumpWidget(
      _host(
        result: result,
        portionGrams: 250,
        onPortionChanged: (_) {},
        onRetake: () {},
        onSelectCandidate: (_) {},
        onScanAgain: () {},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ambigu'), findsOneWidget);
    expect(find.text('Hasil perlu diperiksa'), findsOneWidget);
    expect(
      find.textContaining('Dua prediksi teratas hampir sama kuat'),
      findsOneWidget,
    );
  });
}
