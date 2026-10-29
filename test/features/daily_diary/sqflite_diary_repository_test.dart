import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/features/daily_diary/data/repositories/sqflite_diary_repository.dart';
import 'package:nutriscan/features/daily_diary/domain/entities/diary_entry.dart';
import 'package:nutriscan/features/daily_diary/domain/entities/meal_type.dart';
import 'package:nutriscan/features/food_scan/domain/entities/nutrition_facts.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DiaryEntry _entry({
  required String id,
  required DateTime loggedAt,
  MealType mealType = MealType.lunch,
  String displayName = 'Nasi Goreng',
  String foodLabel = 'nasi_goreng',
  String emoji = '🍛',
  int portionGrams = 250,
  double caloriesKcal = 250,
  double proteinG = 10,
  double carbohydrateG = 30,
  double fatG = 8,
  double fiberG = 2,
  double sodiumMg = 400,
  double confidence = 0.87,
}) {
  return DiaryEntry(
    id: id,
    foodLabel: foodLabel,
    displayName: displayName,
    emoji: emoji,
    mealType: mealType,
    portionGrams: portionGrams,
    portionUnit: 'g',
    nutrition: NutritionFacts(
      caloriesKcal: caloriesKcal,
      proteinG: proteinG,
      carbohydrateG: carbohydrateG,
      fatG: fatG,
      fiberG: fiberG,
      sodiumMg: sodiumMg,
    ),
    confidence: confidence,
    loggedAt: loggedAt,
  );
}

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String databasePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nutriscan_diary_test_');
    databasePath = p.join(tempDir.path, 'diary.db');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
  });

  test('persists entries across repository instances', () async {
    final first = SqfliteDiaryRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(first.close);

    await first.addEntry(
      _entry(
        id: 'older',
        loggedAt: DateTime(2026, 10, 28, 19, 30),
        mealType: MealType.dinner,
        displayName: 'Soto',
        foodLabel: 'soto',
        emoji: '🍲',
        caloriesKcal: 85,
        proteinG: 4.1,
        carbohydrateG: 4.6,
        fatG: 5.6,
        confidence: 0.72,
      ),
    );
    await first.addEntry(
      _entry(
        id: 'newer',
        loggedAt: DateTime(2026, 10, 29, 8, 15),
        mealType: MealType.breakfast,
      ),
    );
    await first.close();

    final second = SqfliteDiaryRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(second.close);

    final entries = await second.loadEntries();

    expect(entries.map((DiaryEntry entry) => entry.id), <String>[
      'newer',
      'older',
    ]);
    final loaded = entries.first;
    expect(loaded.displayName, 'Nasi Goreng');
    expect(loaded.foodLabel, 'nasi_goreng');
    expect(loaded.emoji, '🍛');
    expect(loaded.mealType, MealType.breakfast);
    expect(loaded.portionGrams, 250);
    expect(loaded.portionUnit, 'g');
    expect(loaded.confidence, closeTo(0.87, 1e-9));
    expect(loaded.loggedAt, DateTime(2026, 10, 29, 8, 15));
    expect(loaded.nutrition.caloriesKcal, closeTo(250, 1e-9));
    expect(loaded.nutrition.proteinG, closeTo(10, 1e-9));
    expect(loaded.nutrition.carbohydrateG, closeTo(30, 1e-9));
    expect(loaded.nutrition.fatG, closeTo(8, 1e-9));
    expect(loaded.nutrition.fiberG, closeTo(2, 1e-9));
    expect(loaded.nutrition.sodiumMg, closeTo(400, 1e-9));
  });

  test('returns an empty list before the first entry', () async {
    final repository = SqfliteDiaryRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(repository.close);

    expect(await repository.loadEntries(), isEmpty);
  });
}
