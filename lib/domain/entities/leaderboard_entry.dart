import '../../core/utils/json_codecs.dart';

/// One row of a leaderboard (`leaderboards/{boardId}/entries/{uid}`).
///
/// Display fields are denormalized copies of the profile so rendering a board
/// costs a single query. Cloud Functions keep them in sync on profile edits
/// and on every point change. Board ids: `global`, `weekly-<isoYear>-<isoWeek>`.
class LeaderboardEntry {
  static const int currentSchemaVersion = 1;

  final String uid;
  final String displayName;
  final String? photoUrl;
  final int points;
  final DateTime updatedAt;
  final int schemaVersion;

  const LeaderboardEntry({
    required this.uid,
    required this.displayName,
    this.photoUrl,
    required this.points,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'points': points,
        'updatedAt': dateToJson(updatedAt),
        'schemaVersion': schemaVersion,
      };

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
        uid: stringFromJson(json, 'uid'),
        displayName: stringFromJson(json, 'displayName', fallback: 'Musicista'),
        photoUrl: json['photoUrl'] as String?,
        points: intFromJson(json, 'points'),
        updatedAt: dateFromJson(json['updatedAt']) ?? DateTime.now().toUtc(),
        schemaVersion: intFromJson(json, 'schemaVersion', fallback: 1),
      );
}

/// Well-known board ids.
abstract final class LeaderboardIds {
  static const String global = 'global';

  /// `weekly-2026-28` style id for the ISO week containing [when].
  static String weekly(DateTime when) {
    final utc = when.toUtc();
    // ISO-8601 week number: Thursday of the current week decides the year.
    final thursday = utc.add(Duration(days: 4 - (utc.weekday == 7 ? 7 : utc.weekday)));
    final firstDayOfYear = DateTime.utc(thursday.year, 1, 1);
    final week = 1 + (thursday.difference(firstDayOfYear).inDays ~/ 7);
    return 'weekly-${thursday.year}-${week.toString().padLeft(2, '0')}';
  }
}
