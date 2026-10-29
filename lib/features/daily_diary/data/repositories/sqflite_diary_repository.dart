import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../../food_scan/domain/entities/nutrition_facts.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/entities/meal_type.dart';
import '../../domain/repositories/diary_repository.dart';

/// Persistent diary backed by a local SQLite database.
///
/// The database is opened lazily on the first read/write, which keeps app
/// startup fast and makes this class usable from tests with an injected
/// [DatabaseFactory].
final class SqfliteDiaryRepository implements DiaryRepository {
  SqfliteDiaryRepository({
    DatabaseFactory? databaseFactory,
    this.databasePath,
    this.databaseName = 'nutriscan_diary.db',
  }) : _databaseFactory = databaseFactory ?? databaseFactorySqflitePlugin;

  static const String tableName = 'diary_entries';
  static const int schemaVersion = 1;

  final DatabaseFactory _databaseFactory;
  final String? databasePath;
  final String databaseName;

  Database? _database;
  Future<Database>? _opening;

  Future<Database> _open() {
    final database = _database;
    if (database != null) return Future<Database>.value(database);
    return _opening ??= _openDatabase().whenComplete(() => _opening = null);
  }

  Future<Database> _openDatabase() async {
    final path =
        databasePath ??
        p.join(await _databaseFactory.getDatabasesPath(), databaseName);
    final database = await _databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: schemaVersion,
        onCreate: (Database db, int version) async {
          await db.execute('''
CREATE TABLE $tableName (
  id TEXT PRIMARY KEY,
  food_label TEXT NOT NULL,
  display_name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  meal_type TEXT NOT NULL,
  portion_grams INTEGER NOT NULL,
  portion_unit TEXT NOT NULL,
  calories_kcal REAL NOT NULL,
  protein_g REAL NOT NULL,
  carbohydrate_g REAL NOT NULL,
  fat_g REAL NOT NULL,
  fiber_g REAL NOT NULL,
  sodium_mg REAL NOT NULL,
  confidence REAL NOT NULL,
  logged_at INTEGER NOT NULL
)
''');
          await db.execute(
            'CREATE INDEX idx_${tableName}_logged_at '
            'ON $tableName(logged_at DESC)',
          );
        },
      ),
    );
    _database = database;
    return database;
  }

  @override
  Future<List<DiaryEntry>> loadEntries() async {
    final database = await _open();
    final rows = await database.query(
      tableName,
      orderBy: 'logged_at DESC, id DESC',
    );
    return List<DiaryEntry>.unmodifiable(rows.map(_fromRow));
  }

  @override
  Future<void> addEntry(DiaryEntry entry) async {
    final database = await _open();
    await database.insert(
      tableName,
      _toRow(entry),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Releases the native database handle. The app keeps the repository for its
  /// whole lifetime; tests call this to avoid leaking file handles.
  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }

  static Map<String, Object?> _toRow(DiaryEntry entry) => <String, Object?>{
    'id': entry.id,
    'food_label': entry.foodLabel,
    'display_name': entry.displayName,
    'emoji': entry.emoji,
    'meal_type': entry.mealType.name,
    'portion_grams': entry.portionGrams,
    'portion_unit': entry.portionUnit,
    'calories_kcal': entry.nutrition.caloriesKcal,
    'protein_g': entry.nutrition.proteinG,
    'carbohydrate_g': entry.nutrition.carbohydrateG,
    'fat_g': entry.nutrition.fatG,
    'fiber_g': entry.nutrition.fiberG,
    'sodium_mg': entry.nutrition.sodiumMg,
    'confidence': entry.confidence,
    'logged_at': entry.loggedAt.millisecondsSinceEpoch,
  };

  static DiaryEntry _fromRow(Map<String, Object?> row) {
    final mealName = row['meal_type'];
    final mealType = MealType.values.firstWhere(
      (MealType meal) => meal.name == mealName,
      orElse: () => MealType.snack,
    );
    final loggedAtMillis = _intValue(row['logged_at']);

    return DiaryEntry(
      id: _stringValue(row['id']),
      foodLabel: _stringValue(row['food_label']),
      displayName: _stringValue(row['display_name']),
      emoji: _stringValue(row['emoji'], fallback: '🍽️'),
      mealType: mealType,
      portionGrams: _intValue(row['portion_grams']),
      portionUnit: _stringValue(row['portion_unit'], fallback: 'g'),
      nutrition: NutritionFacts(
        caloriesKcal: _doubleValue(row['calories_kcal']),
        proteinG: _doubleValue(row['protein_g']),
        carbohydrateG: _doubleValue(row['carbohydrate_g']),
        fatG: _doubleValue(row['fat_g']),
        fiberG: _doubleValue(row['fiber_g']),
        sodiumMg: _doubleValue(row['sodium_mg']),
      ),
      confidence: _doubleValue(row['confidence']),
      loggedAt: DateTime.fromMillisecondsSinceEpoch(loggedAtMillis),
    );
  }

  static String _stringValue(Object? value, {String fallback = ''}) =>
      value is String && value.isNotEmpty ? value : fallback;

  static int _intValue(Object? value) => value is num ? value.toInt() : 0;

  static double _doubleValue(Object? value) =>
      value is num ? value.toDouble() : 0;
}
