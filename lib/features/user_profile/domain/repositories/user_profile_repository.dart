import '../entities/user_profile.dart';

/// Persistence boundary for the user's physical profile.
///
/// Production uses a local SQLite implementation, while unit tests use an
/// in-memory implementation. Consumers depend only on this interface.
abstract interface class UserProfileRepository {
  /// Returns the stored profile, or `null` when the user has not saved one yet.
  Future<UserProfile?> loadProfile();

  Future<void> saveProfile(UserProfile profile);
}
