import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/errors/app_failure.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/profile_repository.dart';
import 'firebase_failure_mapper.dart';
import 'firestore_paths.dart';

class FirestoreProfileRepository implements ProfileRepository {
  final FirebaseFirestore _db;

  FirestoreProfileRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.doc(FirestorePaths.user(uid));

  @override
  Stream<UserProfile?> watchProfile(String uid) => _doc(uid)
      .snapshots()
      .map((snap) {
        final data = snap.data();
        return data == null ? null : UserProfile.fromJson(data);
      })
      .handleError((Object e) => throw mapFirebaseError(e));

  @override
  Future<UserProfile?> fetchProfile(String uid) => guard(() async {
        final snap = await _doc(uid).get();
        final data = snap.data();
        return data == null ? null : UserProfile.fromJson(data);
      });

  @override
  Future<UserProfile> ensureProfile(AuthUser user) => guard(() async {
        final now = DateTime.now().toUtc();
        final existing = await fetchProfile(user.uid);
        if (existing != null) {
          // Refresh identity fields that may have changed at the provider
          // (e.g. new Google avatar), never overwriting user-chosen values.
          final refreshed = existing.copyWith(
            email: user.email ?? existing.email,
            photoUrl: existing.photoUrl ?? user.photoUrl,
            updatedAt: now,
          );
          await _doc(user.uid).set(refreshed.toJson(), SetOptions(merge: true));
          return refreshed;
        }
        final profile = UserProfile(
          uid: user.uid,
          email: user.email,
          displayName: user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : (user.email?.split('@').first ?? 'Musicista'),
          photoUrl: user.photoUrl,
          createdAt: now,
          updatedAt: now,
        );
        await _doc(user.uid).set(profile.toJson());
        return profile;
      });

  @override
  Future<void> updateProfile(UserProfile profile) => guard(() {
        // set(merge) rather than update() so offline-created profiles don't
        // race document existence; Firestore applies it locally at once
        // (optimistic) and syncs in the background.
        return _doc(profile.uid).set(
          profile.copyWith(updatedAt: DateTime.now().toUtc()).toJson(),
          SetOptions(merge: true),
        );
      });

  @override
  Future<bool> isUsernameTaken(String username) => guard(() async {
        final handle = username.trim().toLowerCase();
        final snap = await _db.doc(FirestorePaths.username(handle)).get();
        return snap.exists;
      });

  @override
  Future<void> claimUsername({required String uid, required String username}) {
    final handle = username.trim().toLowerCase();
    if (handle.length < 3 || !RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(handle)) {
      throw const DataFormatFailure(
          message: 'Il nome utente deve avere 3-24 caratteri (a-z, 0-9, _).');
    }
    return guard(() async {
      await _db.runTransaction((tx) async {
        final reservation = _db.doc(FirestorePaths.username(handle));
        final existing = await tx.get(reservation);
        if (existing.exists) {
          if (existing.data()?['uid'] != uid) {
            throw const ConflictFailure(message: 'Nome utente già in uso.');
          }
          return; // already ours — idempotent
        }
        final profileRef = _doc(uid);
        final profileSnap = await tx.get(profileRef);
        final previous = profileSnap.data()?['username'] as String?;
        if (previous != null && previous != handle) {
          tx.delete(_db.doc(FirestorePaths.username(previous)));
        }
        tx.set(reservation, {
          'uid': uid,
          'createdAt': DateTime.now().toUtc().millisecondsSinceEpoch,
        });
        tx.set(profileRef, {'username': handle}, SetOptions(merge: true));
      });
    });
  }
}
