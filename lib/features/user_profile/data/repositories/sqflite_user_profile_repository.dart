import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

/// Persistent user profile backed by a local SQLite database.
///
/// The database is opened lazily on the first read/write, which keeps app
/// startup fast and makes this class usable from tests with an injected
/// [DatabaseFactory].
final class SqfliteUserProfileRepository implements UserProfileRepository {
  SqfliteUserProfileRepository({
    DatabaseFactory? databaseFactory,
    this.databasePath,
    this.databaseName = 'nutriscan_profile.db',
  }) : _databaseFactory = databaseFactory ?? databaseFactorySqflitePlugin;

  static const String tableName = 'user_profile';
  static const int schemaVersion = 1;
  static const int _singletonRowId = 1;

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
  id INTEGER PRIMARY KEY,
  weight_kg REAL NOT NULL,
  height_cm REAL NOT NULL,
  age INTEGER NOT NULL,
  gender TEXT NOT NULL,
  activity_level TEXT NOT NULL
)
''');
        },
      ),
    );
    _database = database;
    return database;
  }

  @override
  Future<UserProfile?> loadProfile() async {
    final database = await _open();
    final rows = await database.query(
      tableName,
      where: 'id = ?',
      whereArgs: <Object>[_singletonRowId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return _fromRow(rows.first);
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    final database = await _open();
    await database.insert(
      tableName,
      _toRow(profile),
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

  static Map<String, Object?> _toRow(UserProfile profile) => <String, Object?>{
    'id': _singletonRowId,
    'weight_kg': profile.weightKg,
    'height_cm': profile.heightCm,
    'age': profile.age,
    'gender': profile.gender.name,
    'activity_level': profile.activityLevel.name,
  };

  static UserProfile _fromRow(Map<String, Object?> row) {
    return UserProfile(
      weightKg: _doubleValue(row['weight_kg']),
      heightCm: _doubleValue(row['height_cm']),
      age: _intValue(row['age']),
      gender: _genderValue(row['gender']),
      activityLevel: _activityLevelValue(row['activity_level']),
    );
  }

  static Gender _genderValue(Object? value) {
    for (final gender in Gender.values) {
      if (gender.name == value) return gender;
    }
    return UserProfile.defaultProfile.gender;
  }

  static ActivityLevel _activityLevelValue(Object? value) {
    for (final level in ActivityLevel.values) {
      if (level.name == value) return level;
    }
    return UserProfile.defaultProfile.activityLevel;
  }

  static int _intValue(Object? value) => value is num ? value.toInt() : 0;

  static double _doubleValue(Object? value) =>
      value is num ? value.toDouble() : 0;
}
