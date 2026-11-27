import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/in_memory_user_profile_repository.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

/// Swap this provider for a persistent implementation without touching the UI.
final Provider<UserProfileRepository> userProfileRepositoryProvider =
    Provider<UserProfileRepository>((ref) => InMemoryUserProfileRepository());

/// Loads and persists the physical profile used for TDEE calculation.
final class UserProfileNotifier extends AsyncNotifier<UserProfile> {
  @override
  Future<UserProfile> build() async {
    final stored = await ref.watch(userProfileRepositoryProvider).loadProfile();
    return stored ?? UserProfile.defaultProfile;
  }

  /// Saves the changed fields and updates the in-app profile.
  ///
  /// The state only changes after the write succeeds, so a storage failure
  /// leaves the previous values visible instead of showing unsaved data.
  Future<void> updateProfile({
    double? weightKg,
    double? heightCm,
    int? age,
    Gender? gender,
    ActivityLevel? activityLevel,
  }) async {
    final current = await future;
    final updated = current.copyWith(
      weightKg: weightKg,
      heightCm: heightCm,
      age: age,
      gender: gender,
      activityLevel: activityLevel,
    );
    await ref.read(userProfileRepositoryProvider).saveProfile(updated);
    state = AsyncData<UserProfile>(updated);
  }
}

final AsyncNotifierProvider<UserProfileNotifier, UserProfile>
userProfileProvider = AsyncNotifierProvider<UserProfileNotifier, UserProfile>(
  UserProfileNotifier.new,
);
