import '../../core/utils/json_codecs.dart';

/// The practice surface a workout happened on.
enum WorkoutType { sheetReading, flowMode, polyrhythm, composer }

/// Whether the points on a session are the client's optimistic estimate or
/// the canonical value confirmed by the `onWorkoutCreated` Cloud Function.
enum PointsStatus { provisional, confirmed }

/// One completed practice session (`users/{uid}/workouts/{id}`).
///
/// The client writes the session with a *provisional* point estimate (so the
/// UI updates instantly, including offline); the Cloud Function recomputes
/// the canonical value — including streak bonuses only the server can settle
/// fairly — and flips [pointsStatus] to confirmed.
class WorkoutSession {
  static const int currentSchemaVersion = 1;

  final String id;
  final WorkoutType type;
  final DateTime startedAt;
  final int durationSeconds;
  final int bpm;

  /// 1 (beginner) … 5 (expert). Numeric so the point formula is locale-free.
  final int difficultyLevel;

  /// 0..1 reading accuracy, when the mode can measure it.
  final double? accuracy;

  /// Id of the generated exercise or composition practiced, if any.
  final String? sourceId;

  final int pointsEarned;
  final PointsStatus pointsStatus;
  final DateTime createdAt;
  final int schemaVersion;

  const WorkoutSession({
    required this.id,
    required this.type,
    required this.startedAt,
    required this.durationSeconds,
    required this.bpm,
    this.difficultyLevel = 1,
    this.accuracy,
    this.sourceId,
    this.pointsEarned = 0,
    this.pointsStatus = PointsStatus.provisional,
    required this.createdAt,
    this.schemaVersion = currentSchemaVersion,
  });

  WorkoutSession copyWith({
    String? id,
    int? pointsEarned,
    PointsStatus? pointsStatus,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      type: type,
      startedAt: startedAt,
      durationSeconds: durationSeconds,
      bpm: bpm,
      difficultyLevel: difficultyLevel,
      accuracy: accuracy,
      sourceId: sourceId,
      pointsEarned: pointsEarned ?? this.pointsEarned,
      pointsStatus: pointsStatus ?? this.pointsStatus,
      createdAt: createdAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'startedAt': dateToJson(startedAt),
        'durationSeconds': durationSeconds,
        'bpm': bpm,
        'difficultyLevel': difficultyLevel,
        'accuracy': accuracy,
        'sourceId': sourceId,
        'pointsEarned': pointsEarned,
        'pointsStatus': pointsStatus.name,
        'createdAt': dateToJson(createdAt),
        'schemaVersion': schemaVersion,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    return WorkoutSession(
      id: stringFromJson(json, 'id'),
      type: WorkoutType.values.asNameMap()[json['type']] ?? WorkoutType.sheetReading,
      startedAt: dateFromJson(json['startedAt']) ?? now,
      durationSeconds: intFromJson(json, 'durationSeconds'),
      bpm: intFromJson(json, 'bpm', fallback: 100),
      difficultyLevel: intFromJson(json, 'difficultyLevel', fallback: 1),
      accuracy: doubleFromJson(json, 'accuracy'),
      sourceId: json['sourceId'] as String?,
      pointsEarned: intFromJson(json, 'pointsEarned'),
      pointsStatus: PointsStatus.values.asNameMap()[json['pointsStatus']] ??
          PointsStatus.provisional,
      createdAt: dateFromJson(json['createdAt']) ?? now,
      schemaVersion: intFromJson(json, 'schemaVersion', fallback: 1),
    );
  }
}
