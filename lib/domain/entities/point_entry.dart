import '../../core/utils/json_codecs.dart';

/// Where a point-history entry came from.
enum PointSource { workout, achievement, bonus, adjustment }

/// One immutable ledger line (`users/{uid}/pointHistory/{id}`).
///
/// The ledger is written only by Cloud Functions; the running total in
/// [UserStatistics.totalPoints] always equals the sum of this ledger, which
/// makes point balances auditable and recomputable.
class PointEntry {
  static const int currentSchemaVersion = 1;

  final String id;
  final PointSource source;
  final int points;

  /// Back-reference to the workout or achievement that produced the entry.
  final String? referenceId;

  final String description;
  final DateTime createdAt;
  final int schemaVersion;

  const PointEntry({
    required this.id,
    required this.source,
    required this.points,
    this.referenceId,
    this.description = '',
    required this.createdAt,
    this.schemaVersion = currentSchemaVersion,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source.name,
        'points': points,
        'referenceId': referenceId,
        'description': description,
        'createdAt': dateToJson(createdAt),
        'schemaVersion': schemaVersion,
      };

  factory PointEntry.fromJson(Map<String, dynamic> json) => PointEntry(
        id: stringFromJson(json, 'id'),
        source: PointSource.values.asNameMap()[json['source']] ?? PointSource.bonus,
        points: intFromJson(json, 'points'),
        referenceId: json['referenceId'] as String?,
        description: stringFromJson(json, 'description'),
        createdAt: dateFromJson(json['createdAt']) ?? DateTime.now().toUtc(),
        schemaVersion: intFromJson(json, 'schemaVersion', fallback: 1),
      );
}
