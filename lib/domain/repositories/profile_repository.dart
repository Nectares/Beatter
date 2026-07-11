import '../entities/auth_user.dart';
import '../entities/user_profile.dart';

/// User profile document access.
abstract interface class ProfileRepository {
  /// Live profile of [uid]; emits null while the doc doesn't exist yet.
  Stream<UserProfile?> watchProfile(String uid);

  Future<UserProfile?> fetchProfile(String uid);

  /// Creates the profile document on first sign-in (idempotent: merges basic
  /// identity fields if the doc already exists). Called by the session
  /// manager right after authentication.
  Future<UserProfile> ensureProfile(AuthUser user);

  /// Optimistic update: local cache reflects the change immediately.
  Future<void> updateProfile(UserProfile profile);

  /// Atomically reserves [username] (case-insensitive) and stores it on the
  /// profile. Throws [ConflictFailure] if taken.
  Future<void> claimUsername({required String uid, required String username});

  /// Whether [username] (case-insensitive) is already reserved by another
  /// user. A pre-flight check for registration forms — [claimUsername] stays
  /// the authoritative, race-free gate.
  Future<bool> isUsernameTaken(String username);
}
