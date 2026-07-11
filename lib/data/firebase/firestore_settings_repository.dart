import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/user_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import 'firebase_failure_mapper.dart';
import 'firestore_paths.dart';

class FirestoreSettingsRepository implements SettingsRepository {
  final FirebaseFirestore _db;

  FirestoreSettingsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.doc(FirestorePaths.settings(uid));

  @override
  Stream<UserSettings> watchSettings(String uid) => _doc(uid)
      .snapshots()
      .map((snap) {
        final data = snap.data();
        return data == null ? UserSettings.defaults() : UserSettings.fromJson(data);
      })
      .handleError((Object e) => throw mapFirebaseError(e));

  @override
  Future<UserSettings> fetchSettings(String uid) => guard(() async {
        final snap = await _doc(uid).get();
        final data = snap.data();
        return data == null ? UserSettings.defaults() : UserSettings.fromJson(data);
      });

  @override
  Future<void> saveSettings(String uid, UserSettings settings) => guard(() {
        return _doc(uid).set(
          settings.copyWith(updatedAt: DateTime.now().toUtc()).toJson(),
        );
      });
}
