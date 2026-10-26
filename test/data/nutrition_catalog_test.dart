import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/core/utils/formatters.dart';
import 'package:nutriscan/features/food_scan/data/datasources/nutrition_catalog_data_source.dart';
import 'package:nutriscan/features/food_scan/data/models/nutrition_catalog_model.dart';
import 'package:nutriscan/features/food_scan/data/repositories/nutrition_repository_impl.dart';

final class _FakeDataSource implements NutritionCatalogDataSource {
  const _FakeDataSource(this.model);

  final NutritionCatalogModel model;

  @override
  Future<NutritionCatalogModel> loadCatalog() async => model;
}

void main() {
  late NutritionCatalogModel catalog;
  late Map<String, dynamic> classNames;

  setUpAll(() {
    final raw = File('assets/data/nutrition_data.json').readAsStringSync();
    catalog = NutritionCatalogModel.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
    classNames = jsonDecode(
      File('assets/data/class_names.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  test('asset catalog matches the exported model contract', () {
    expect(catalog.schemaVersion, 1);
    expect(catalog.classes, hasLength(13));
    expect(catalog.classes.map((entry) => entry.label), <String>[
      'Ayam Goreng',
      'Burger',
      'French Fries',
      'Gado-Gado',
      'Ikan Goreng',
      'Mie Goreng',
      'Nasi Goreng',
      'Nasi Padang',
      'Pizza',
      'Rawon',
      'Rendang',
      'Sate',
      'Soto',
    ]);
    for (var index = 0; index < catalog.classes.length; index++) {
      final entry = catalog.classes[index];
      expect(entry.classIndex, index);
      expect(entry.per100g.caloriesKcal, greaterThan(0));
      expect(entry.defaultPortionGrams, greaterThan(0));
    }
  });

  test('class names declare the model hash and calibration temperature', () {
    expect(classNames['schemaVersion'], 1);
    expect(classNames['classCount'], 13);
    expect(classNames['labels'], catalog.classes.map((entry) => entry.label));
    expect(classNames['primaryModel'], 'food_classifier.tflite');
    expect(classNames['quantization'], anyOf('fp16', 'dynamic'));
    expect((classNames['modelSha256'] as String), hasLength(64));
    final temperature = classNames['confidenceTemperature'] as num;
    expect(temperature, inInclusiveRange(0.1, 10));
    expect(
      File('assets/models/food_classifier.tflite').lengthSync(),
      greaterThan(0),
    );
  });

  test('repository performs index, label, and alias lookups', () async {
    final repository = NutritionRepositoryImpl(_FakeDataSource(catalog));
    await repository.initialize();

    expect(repository.findByIndex(6)?.displayName, 'Nasi Goreng');
    expect(repository.findByLabel('Nasi Goreng')?.classIndex, 6);
    expect(repository.findByLabel('nasgor')?.classIndex, 6);
    expect(repository.findByLabel('tidak ada'), isNull);
    expect(repository.entries, hasLength(13));
  });

  test('category drives the exported portion metadata', () {
    final nasiGoreng = catalog.classes.firstWhere(
      (entry) => entry.label == 'Nasi Goreng',
    );

    expect(nasiGoreng.category, 'main');
    expect(nasiGoreng.defaultPortionGrams, 250);
    expect(portionUnitForCategory('beverage'), 'ml');
    expect(portionUnitForCategory('main'), 'g');
  });
}
