import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_profile_repository.dart';

/// Volatile profile store used by tests and as the default provider value.
final class InMemoryUserProfileRepository implements UserProfileRepository {
  InMemoryUserProfileRepository({UserProfile? initialProfile})
    : _profile = initialProfile;

  UserProfile? _profile;

  @override
  Future<UserProfile?> loadProfile() async => _profile;

  @override
  Future<void> saveProfile(UserProfile profile) async {
    _profile = profile;
  }
}
