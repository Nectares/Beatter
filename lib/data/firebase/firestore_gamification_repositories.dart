import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/achievement.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/point_entry.dart';
import '../../domain/entities/user_statistics.dart';
import '../../domain/repositories/gamification_repositories.dart';
import 'firebase_failure_mapper.dart';
import 'firestore_paths.dart';

/// Read-only Firestore views of the server-maintained gamification data.
/// All writes happen in Cloud Functions (see functions/src/index.ts).

class FirestoreStatisticsRepository implements StatisticsRepository {
  final FirebaseFirestore _db;

  FirestoreStatisticsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      _db.doc(FirestorePaths.statsSummary(uid));

  @override
  Stream<UserStatistics> watchStatistics(String uid) => _doc(uid)
      .snapshots()
      .map((snap) {
        final data = snap.data();
        return data == null ? UserStatistics.empty() : UserStatistics.fromJson(data);
      })
      .handleError((Object e) => throw mapFirebaseError(e));

  @override
  Future<UserStatistics> fetchStatistics(String uid) => guard(() async {
        final snap = await _doc(uid).get();
        final data = snap.data();
        return data == null ? UserStatistics.empty() : UserStatistics.fromJson(data);
      });
}

class FirestorePointsRepository implements PointsRepository {
  final FirebaseFirestore _db;

  FirestorePointsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<PointEntry>> watchHistory(String uid, {int limit = 50}) => _db
      .collection(FirestorePaths.pointHistory(uid))
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => PointEntry.fromJson(d.data())).toList(growable: false))
      .handleError((Object e) => throw mapFirebaseError(e));
}

class FirestoreAchievementsRepository implements AchievementsRepository {
  final FirebaseFirestore _db;

  FirestoreAchievementsRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<UnlockedAchievement>> watchUnlocked(String uid) => _db
      .collection(FirestorePaths.achievements(uid))
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => UnlockedAchievement.fromJson(d.data()))
          .toList(growable: false))
      .handleError((Object e) => throw mapFirebaseError(e));
}

class FirestoreLeaderboardRepository implements LeaderboardRepository {
  final FirebaseFirestore _db;

  FirestoreLeaderboardRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Stream<List<LeaderboardEntry>> watchTop(String boardId, {int limit = 100}) =>
      _db
          .collection(FirestorePaths.leaderboardEntries(boardId))
          .orderBy('points', descending: true)
          .orderBy('updatedAt') // ties: earlier scorer ranks first
          .limit(limit)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => LeaderboardEntry.fromJson(d.data()))
              .toList(growable: false))
          .handleError((Object e) => throw mapFirebaseError(e));

  @override
  Stream<LeaderboardEntry?> watchEntry(String boardId, String uid) => _db
      .collection(FirestorePaths.leaderboardEntries(boardId))
      .doc(uid)
      .snapshots()
      .map((snap) {
        final data = snap.data();
        return data == null ? null : LeaderboardEntry.fromJson(data);
      })
      .handleError((Object e) => throw mapFirebaseError(e));
}
