import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/core/theme/app_theme.dart';
import 'package:nutriscan/features/food_scan/domain/entities/food_nutrition.dart';
import 'package:nutriscan/features/food_scan/domain/entities/food_recognition.dart';
import 'package:nutriscan/features/food_scan/domain/entities/nutrition_facts.dart';
import 'package:nutriscan/features/food_scan/domain/repositories/food_classifier.dart';
import 'package:nutriscan/features/food_scan/domain/repositories/nutrition_repository.dart';
import 'package:nutriscan/features/food_scan/domain/usecases/scan_food.dart';
import 'package:nutriscan/features/food_scan/presentation/controllers/scan_controller.dart';
import 'package:nutriscan/features/food_scan/presentation/providers/scan_providers.dart';
import 'package:nutriscan/features/food_scan/presentation/screens/scanner_screen.dart';

/// 1x1 transparent PNG, enough to exercise `Image.memory` in the stage card.
final Uint8List _tinyPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAE'
  'hQGAhKmMIQAAAABJRU5ErkJggg==',
);

final class _FakeClassifier implements FoodClassifier {
  @override
  Future<void> initialize() async {}

  @override
  Future<List<FoodRecognition>> classify(
    Uint8List imageBytes, {
    int topK = 3,
  }) async {
    return const <FoodRecognition>[
      FoodRecognition(classIndex: 4, label: 'fried_noodles', confidence: 0.87),
    ];
  }

  @override
  Future<void> dispose() async {}
}

final class _FakeNutritionRepository implements NutritionRepository {
  static const FoodNutrition _food = FoodNutrition(
    classIndex: 4,
    label: 'fried_noodles',
    displayName: 'Mie Goreng',
    emoji: '🍜',
    per100g: NutritionFacts(
      caloriesKcal: 190,
      proteinG: 4.2,
      carbohydrateG: 22.4,
      fatG: 6.8,
      fiberG: 1.2,
      sodiumMg: 420,
    ),
    defaultPortionGrams: 220,
  );

  @override
  Future<void> initialize() async {}

  @override
  List<FoodNutrition> get entries => const <FoodNutrition>[_food];

  @override
  FoodNutrition? findByIndex(int classIndex) =>
      classIndex == _food.classIndex ? _food : null;

  @override
  FoodNutrition? findByLabel(String label) =>
      label == _food.label ? _food : null;
}

void main() {
  testWidgets('result content keeps space above the diary action bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final container = ProviderContainer(
      overrides: [
        scanFoodUseCaseProvider.overrideWithValue(
          ScanFoodUseCase(_FakeClassifier(), _FakeNutritionRepository()),
        ),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.light, home: const ScannerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await container
        .read(scanControllerProvider.notifier)
        .classifyBytes(_tinyPng);
    await tester.pumpAndSettle();

    expect(find.text('Olahan Mie'), findsOneWidget);
    expect(find.text('Ringkasan gizi'), findsOneWidget);
    // The 390 px test surface uses the compact "Simpan" label.
    expect(find.text('Simpan'), findsOneWidget);

    final barText = tester.getRect(find.text('Simpan'));
    // The bar must sit at the bottom of the viewport instead of expanding to
    // the full scaffold height (which previously left the body with 0 px).
    expect(barText.top, greaterThan(700));
    expect(barText.bottom, lessThanOrEqualTo(844));
  });
}
