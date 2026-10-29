import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/food_label_localizer.dart';
import '../../../../core/utils/formatters.dart';
import '../../../food_scan/domain/entities/food_candidate.dart';
import '../../data/repositories/in_memory_diary_repository.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/repositories/diary_repository.dart';

/// Swap this provider for a persistent implementation without touching the UI.
final Provider<DiaryRepository> diaryRepositoryProvider =
    Provider<DiaryRepository>((ref) => InMemoryDiaryRepository());

/// Owns the diary list and the save operation.
///
/// Widgets only render [DiaryEntry] values and call [saveMeal]; all mapping,
/// portion scaling, and list mutation live here.
final class DiaryController extends AsyncNotifier<List<DiaryEntry>> {
  @override
  Future<List<DiaryEntry>> build() =>
      ref.watch(diaryRepositoryProvider).loadEntries();

  Future<DiaryEntry> saveMeal({
    required FoodCandidate candidate,
    required int portionGrams,
    required MealType mealType,
    required double confidence,
    DateTime? loggedAt,
  }) async {
    final timestamp = loggedAt ?? DateTime.now();
    final food = candidate.food;
    final entry = DiaryEntry(
      id: timestamp.microsecondsSinceEpoch.toString(),
      foodLabel: food.label,
      displayName: FoodLabelLocalizer.resolve(
        food.label,
        displayName: food.displayName,
      ),
      emoji: food.emoji,
      mealType: mealType,
      portionGrams: portionGrams,
      portionUnit: portionUnitForCategory(food.category),
      nutrition: candidate.nutritionForPortion(portionGrams),
      confidence: confidence,
      loggedAt: timestamp,
    );

    await ref.read(diaryRepositoryProvider).addEntry(entry);
    final current = state.value ?? const <DiaryEntry>[];
    state = AsyncData<List<DiaryEntry>>(<DiaryEntry>[entry, ...current]);
    return entry;
  }

  /// Entries logged on the same calendar day as [now].
  List<DiaryEntry> entriesForDay(DateTime now) {
    final entries = state.value ?? const <DiaryEntry>[];
    return entries
        .where((entry) => entry.isSameDay(now))
        .toList(growable: false);
  }
}

final AsyncNotifierProvider<DiaryController, List<DiaryEntry>>
diaryControllerProvider =
    AsyncNotifierProvider<DiaryController, List<DiaryEntry>>(
      DiaryController.new,
    );
