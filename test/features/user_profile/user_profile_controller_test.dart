import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nutriscan/features/user_profile/data/repositories/in_memory_user_profile_repository.dart';
import 'package:nutriscan/features/user_profile/domain/entities/user_profile.dart';
import 'package:nutriscan/features/user_profile/domain/repositories/user_profile_repository.dart';
import 'package:nutriscan/features/user_profile/presentation/providers/user_profile_providers.dart';

void main() {
  test('loads the default profile when storage is empty', () async {
    final repository = InMemoryUserProfileRepository();
    final container = ProviderContainer(
      overrides: [userProfileRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final profile = await container.read(userProfileProvider.future);

    expect(profile.weightKg, closeTo(70, 1e-9));
    expect(profile.heightCm, closeTo(170, 1e-9));
    expect(profile.age, 25);
    expect(profile.gender, Gender.male);
    expect(profile.activityLevel, ActivityLevel.sedentary);
  });

  test('updateProfile saves the changes and reloads them', () async {
    final repository = InMemoryUserProfileRepository();
    final first = ProviderContainer(
      overrides: [userProfileRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(first.dispose);
    await first.read(userProfileProvider.future);

    await first
        .read(userProfileProvider.notifier)
        .updateProfile(
          weightKg: 82.5,
          heightCm: 178,
          age: 31,
          gender: Gender.female,
          activityLevel: ActivityLevel.veryActive,
        );

    final stored = await repository.loadProfile();
    expect(stored, isNotNull);
    expect(stored!.weightKg, closeTo(82.5, 1e-9));
    expect(stored.gender, Gender.female);

    final second = ProviderContainer(
      overrides: [userProfileRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(second.dispose);
    final reloaded = await second.read(userProfileProvider.future);

    expect(reloaded.weightKg, closeTo(82.5, 1e-9));
    expect(reloaded.heightCm, closeTo(178, 1e-9));
    expect(reloaded.age, 31);
    expect(reloaded.gender, Gender.female);
    expect(reloaded.activityLevel, ActivityLevel.veryActive);
  });

  test('a failed save keeps the previously loaded profile', () async {
    final repository = _FailingUserProfileRepository();
    final container = ProviderContainer(
      overrides: [userProfileRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    final initial = await container.read(userProfileProvider.future);

    await expectLater(
      container.read(userProfileProvider.notifier).updateProfile(weightKg: 90),
      throwsStateError,
    );

    final current = container.read(userProfileProvider).value;
    expect(current, isNotNull);
    expect(current!.weightKg, closeTo(initial.weightKg, 1e-9));
  });
}

final class _FailingUserProfileRepository implements UserProfileRepository {
  @override
  Future<UserProfile?> loadProfile() async => null;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    throw StateError('Simulated storage failure.');
  }
}
