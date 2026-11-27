import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/features/user_profile/data/repositories/sqflite_user_profile_repository.dart';
import 'package:nutriscan/features/user_profile/domain/entities/user_profile.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const UserProfile _profile = UserProfile(
  weightKg: 82.5,
  heightCm: 178,
  age: 31,
  gender: Gender.female,
  activityLevel: ActivityLevel.veryActive,
);

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String databasePath;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('nutriscan_profile_test_');
    databasePath = p.join(tempDir.path, 'profile.db');
    addTearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });
  });

  test('returns null before the user saves a profile', () async {
    final repository = SqfliteUserProfileRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(repository.close);

    expect(await repository.loadProfile(), isNull);
  });

  test('persists the profile across repository instances', () async {
    final first = SqfliteUserProfileRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(first.close);

    await first.saveProfile(_profile);
    await first.close();

    final second = SqfliteUserProfileRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(second.close);

    final loaded = await second.loadProfile();

    expect(loaded, isNotNull);
    expect(loaded!.weightKg, closeTo(82.5, 1e-9));
    expect(loaded.heightCm, closeTo(178, 1e-9));
    expect(loaded.age, 31);
    expect(loaded.gender, Gender.female);
    expect(loaded.activityLevel, ActivityLevel.veryActive);
  });

  test('saving again replaces the single stored row', () async {
    final repository = SqfliteUserProfileRepository(
      databaseFactory: databaseFactoryFfi,
      databasePath: databasePath,
    );
    addTearDown(repository.close);

    await repository.saveProfile(_profile);
    await repository.saveProfile(_profile.copyWith(weightKg: 79));

    final loaded = await repository.loadProfile();

    expect(loaded, isNotNull);
    expect(loaded!.weightKg, closeTo(79, 1e-9));
    expect(loaded.age, 31);
  });
}
