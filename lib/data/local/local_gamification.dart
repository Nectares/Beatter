import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/utils/value_stream.dart';
import '../../domain/entities/achievement.dart';
import '../../domain/entities/auth_user.dart';
import '../../domain/entities/leaderboard_entry.dart';
import '../../domain/entities/point_entry.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/entities/user_settings.dart';
import '../../domain/entities/user_statistics.dart';
import '../../domain/entities/workout_session.dart';
import '../../domain/logic/achievement_rules.dart';
import '../../domain/logic/point_rules.dart';
import '../../domain/repositories/gamification_repositories.dart';
import '../../domain/repositories/profile_repository.dart';
import '../../domain/repositories/settings_repository.dart';
import '../../domain/repositories/workout_repository.dart';

/// Local-mode gamification engine: applies the same [PointRules] and
/// [AchievementRules] the Cloud Function applies in production, but against
/// shared_preferences. Points recorded here are immediately `confirmed`
/// (there is no server to defer to).
///
/// One engine instance backs all the small repository adapters below so
/// stats/ledger/achievements stay mutually consistent.
class LocalGamificationEngine {
  static const _statsKey = 'backend.local.stats.v1';
  static const _ledgerKey = 'backend.local.pointHistory.v1';
  static const _achievementsKey = 'backend.local.achievements.v1';
  static const _workoutsKey = 'backend.local.workouts.v1';

  final _statsController = StreamController<UserStatistics>.broadcast();
  final _ledgerController = StreamController<List<PointEntry>>.broadcast();
  final _achievementsController =
      StreamController<List<UnlockedAchievement>>.broadcast();
  final _workoutsController = StreamController<List<WorkoutSession>>.broadcast();

  UserStatistics _stats = UserStatistics.empty();
  List<PointEntry> _ledger = [];
  List<UnlockedAchievement> _achievements = [];
  List<WorkoutSession> _workouts = [];
  bool _loaded = false;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    try {
      final stats = prefs.getString(_statsKey);
      if (stats != null) {
        _stats = UserStatistics.fromJson(jsonDecode(stats) as Map<String, dynamic>);
      }
      _ledger = _decodeList(prefs.getString(_ledgerKey), PointEntry.fromJson);
      _achievements =
          _decodeList(prefs.getString(_achievementsKey), UnlockedAchievement.fromJson);
      _workouts = _decodeList(prefs.getString(_workoutsKey), WorkoutSession.fromJson);
    } catch (_) {
      // Corrupt local data: reset rather than crash.
      _stats = UserStatistics.empty();
      _ledger = [];
      _achievements = [];
      _workouts = [];
    }
  }

  static List<T> _decodeList<T>(
      String? raw, T Function(Map<String, dynamic>) fromJson) {
    if (raw == null) return [];
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return (decoded['items'] as List? ?? [])
        .map((e) => fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_statsKey, jsonEncode(_stats.toJson()));
    await prefs.setString(_ledgerKey,
        jsonEncode({'items': _ledger.map((e) => e.toJson()).toList()}));
    await prefs.setString(_achievementsKey,
        jsonEncode({'items': _achievements.map((e) => e.toJson()).toList()}));
    await prefs.setString(_workoutsKey,
        jsonEncode({'items': _workouts.map((e) => e.toJson()).toList()}));
  }

  void _emitAll() {
    _statsController.add(_stats);
    _ledgerController.add(List.unmodifiable(_ledger));
    _achievementsController.add(List.unmodifiable(_achievements));
    _workoutsController.add(List.unmodifiable(_workouts));
  }

  Future<UserStatistics> stats() async {
    await _ensureLoaded();
    return _stats;
  }

  Stream<UserStatistics> watchStats() => valueThenUpdates(
        ensureLoaded: _ensureLoaded,
        snapshot: () => _stats,
        updates: _statsController.stream,
      );

  Stream<List<PointEntry>> watchLedger() => valueThenUpdates(
        ensureLoaded: _ensureLoaded,
        snapshot: () => List.unmodifiable(_ledger),
        updates: _ledgerController.stream,
      );

  Stream<List<UnlockedAchievement>> watchAchievements() => valueThenUpdates(
        ensureLoaded: _ensureLoaded,
        snapshot: () => List.unmodifiable(_achievements),
        updates: _achievementsController.stream,
      );

  Stream<List<WorkoutSession>> watchWorkouts() => valueThenUpdates(
        ensureLoaded: _ensureLoaded,
        snapshot: () => List.unmodifiable(_workouts),
        updates: _workoutsController.stream,
      );

  List<WorkoutSession> get workoutsSnapshot => List.unmodifiable(_workouts);

  /// Mirrors functions/src/index.ts `onWorkoutCreated`.
  Future<WorkoutSession> recordWorkout(WorkoutSession draft) async {
    await _ensureLoaded();
    final now = DateTime.now().toUtc();
    final streak = PointRules.nextStreakDays(_stats, draft.startedAt);
    final points = PointRules.totalFor(draft, streakDaysIncludingToday: streak);
    final session = draft.copyWith(
      id: draft.id.isEmpty ? 'local-${now.microsecondsSinceEpoch}' : draft.id,
      pointsEarned: points,
      pointsStatus: PointsStatus.confirmed,
    );

    _workouts.insert(0, session);
    _ledger.insert(
      0,
      PointEntry(
        id: 'w-${session.id}',
        source: PointSource.workout,
        points: points,
        referenceId: session.id,
        description: 'Allenamento ${session.type.name}',
        createdAt: now,
      ),
    );

    final byType = Map<String, int>.from(_stats.workoutsByType);
    byType[session.type.name] = (byType[session.type.name] ?? 0) + 1;
    _stats = _stats.copyWith(
      totalPoints: _stats.totalPoints + points,
      weeklyPoints: _stats.weeklyPoints + points,
      totalWorkouts: _stats.totalWorkouts + 1,
      totalDurationSeconds: _stats.totalDurationSeconds + session.durationSeconds,
      workoutsByType: byType,
      currentStreakDays: streak,
      longestStreakDays:
          streak > _stats.longestStreakDays ? streak : _stats.longestStreakDays,
      lastWorkoutAt: session.startedAt,
      updatedAt: now,
    );

    for (final def in AchievementRules.newlyUnlocked(
      _stats,
      alreadyUnlockedIds: _achievements.map((a) => a.definitionId).toSet(),
    )) {
      _achievements.add(UnlockedAchievement(
        definitionId: def.id,
        unlockedAt: now,
        rewardPoints: def.rewardPoints,
      ));
      _ledger.insert(
        0,
        PointEntry(
          id: 'a-${def.id}',
          source: PointSource.achievement,
          points: def.rewardPoints,
          referenceId: def.id,
          description: def.title,
          createdAt: now,
        ),
      );
      _stats = _stats.copyWith(
        totalPoints: _stats.totalPoints + def.rewardPoints,
        weeklyPoints: _stats.weeklyPoints + def.rewardPoints,
      );
    }

    _emitAll();
    await _persist();
    return session;
  }
}

class LocalWorkoutRepository implements WorkoutRepository {
  final LocalGamificationEngine _engine;

  LocalWorkoutRepository(this._engine);

  @override
  Future<WorkoutSession> recordSession(String uid, WorkoutSession draft) =>
      _engine.recordWorkout(draft);

  @override
  Stream<List<WorkoutSession>> watchRecent(String uid, {int limit = 50}) =>
      _engine.watchWorkouts().map((list) => list.take(limit).toList());

  @override
  Future<List<WorkoutSession>> fetchPage(
    String uid, {
    DateTime? startAfter,
    int limit = 30,
    WorkoutType? type,
  }) async {
    Iterable<WorkoutSession> items = _engine.workoutsSnapshot;
    if (type != null) items = items.where((w) => w.type == type);
    if (startAfter != null) {
      items = items.where((w) => w.startedAt.isBefore(startAfter));
    }
    return items.take(limit).toList();
  }
}

class LocalStatisticsRepository implements StatisticsRepository {
  final LocalGamificationEngine _engine;

  LocalStatisticsRepository(this._engine);

  @override
  Stream<UserStatistics> watchStatistics(String uid) => _engine.watchStats();

  @override
  Future<UserStatistics> fetchStatistics(String uid) => _engine.stats();
}

class LocalPointsRepository implements PointsRepository {
  final LocalGamificationEngine _engine;

  LocalPointsRepository(this._engine);

  @override
  Stream<List<PointEntry>> watchHistory(String uid, {int limit = 50}) =>
      _engine.watchLedger().map((list) => list.take(limit).toList());
}

class LocalAchievementsRepository implements AchievementsRepository {
  final LocalGamificationEngine _engine;

  LocalAchievementsRepository(this._engine);

  @override
  Stream<List<UnlockedAchievement>> watchUnlocked(String uid) =>
      _engine.watchAchievements();
}

/// Local mode has no other players: the board contains just the local user.
class LocalLeaderboardRepository implements LeaderboardRepository {
  final LocalGamificationEngine _engine;
  final AuthUser? Function() _currentUser;

  LocalLeaderboardRepository(this._engine, this._currentUser);

  LeaderboardEntry _entryFor(UserStatistics stats) {
    final user = _currentUser();
    return LeaderboardEntry(
      uid: user?.uid ?? 'local',
      displayName: user?.displayName ?? 'Tu',
      photoUrl: user?.photoUrl,
      points: stats.totalPoints,
      updatedAt: stats.updatedAt,
    );
  }

  @override
  Stream<List<LeaderboardEntry>> watchTop(String boardId, {int limit = 100}) =>
      _engine.watchStats().map((stats) => [_entryFor(stats)]);

  @override
  Stream<LeaderboardEntry?> watchEntry(String boardId, String uid) =>
      _engine.watchStats().map(_entryFor);
}

class LocalSettingsRepository implements SettingsRepository {
  static const _key = 'backend.local.settings.v1';

  final _controller = StreamController<UserSettings>.broadcast();
  UserSettings? _cached;

  @override
  Future<UserSettings> fetchSettings(String uid) async {
    if (_cached != null) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    _cached = raw == null
        ? UserSettings.defaults()
        : UserSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return _cached!;
  }

  @override
  Stream<UserSettings> watchSettings(String uid) => valueThenUpdates(
        ensureLoaded: () => fetchSettings(uid),
        snapshot: () => _cached ?? UserSettings.defaults(),
        updates: _controller.stream,
      );

  @override
  Future<void> saveSettings(String uid, UserSettings settings) async {
    _cached = settings.copyWith(updatedAt: DateTime.now().toUtc());
    _controller.add(_cached!);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_cached!.toJson()));
  }
}

class LocalProfileRepository implements ProfileRepository {
  static const _key = 'backend.local.profile.v1';

  final _controller = StreamController<UserProfile?>.broadcast();
  UserProfile? _cached;

  @override
  Future<UserProfile?> fetchProfile(String uid) async {
    if (_cached != null) return _cached;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      _cached = UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
    return _cached;
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) => valueThenUpdates(
        ensureLoaded: () => fetchProfile(uid),
        snapshot: () => _cached,
        updates: _controller.stream,
      );

  @override
  Future<UserProfile> ensureProfile(AuthUser user) async {
    final existing = await fetchProfile(user.uid);
    if (existing != null && existing.uid == user.uid) return existing;
    final now = DateTime.now().toUtc();
    final profile = UserProfile(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName ?? user.email?.split('@').first ?? 'Musicista',
      photoUrl: user.photoUrl,
      role: user.email == 'admin@beatter.com'
          ? UserProfileRole.admin
          : UserProfileRole.user,
      createdAt: now,
      updatedAt: now,
    );
    await updateProfile(profile);
    return profile;
  }

  @override
  Future<void> updateProfile(UserProfile profile) async {
    _cached = profile;
    _controller.add(profile);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }

  @override
  Future<void> claimUsername({required String uid, required String username}) async {
    final profile = await fetchProfile(uid);
    if (profile == null) return;
    await updateProfile(profile.copyWith(
      username: username.trim().toLowerCase(),
      updatedAt: DateTime.now().toUtc(),
    ));
  }
}
