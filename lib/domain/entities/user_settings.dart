import '../../core/utils/json_codecs.dart';

/// Per-user preferences (`users/{uid}/settings/main`).
///
/// Split from [UserProfile] so profile reads (which other users may eventually
/// perform for social features) never expose private preferences, and so
/// settings writes don't bump the profile's `updatedAt` denormalization.
class UserSettings {
  static const int currentSchemaVersion = 1;

  final int defaultBpm;
  final String defaultTimeSignature;
  final int defaultDifficultyLevel;
  final bool soundEnabled;
  final bool hapticFeedbackEnabled;
  final bool notificationsEnabled;
  final String locale;
  final DateTime updatedAt;
  final int schemaVersion;

  const UserSettings({
    this.defaultBpm = 100,
    this.defaultTimeSignature = '4/4',
    this.defaultDifficultyLevel = 1,
    this.soundEnabled = true,
    this.hapticFeedbackEnabled = true,
    this.notificationsEnabled = true,
    this.locale = 'it',
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  factory UserSettings.defaults() => UserSettings(updatedAt: DateTime.now().toUtc());

  UserSettings copyWith({
    int? defaultBpm,
    String? defaultTimeSignature,
    int? defaultDifficultyLevel,
    bool? soundEnabled,
    bool? hapticFeedbackEnabled,
    bool? notificationsEnabled,
    String? locale,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      defaultBpm: defaultBpm ?? this.defaultBpm,
      defaultTimeSignature: defaultTimeSignature ?? this.defaultTimeSignature,
      defaultDifficultyLevel: defaultDifficultyLevel ?? this.defaultDifficultyLevel,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticFeedbackEnabled: hapticFeedbackEnabled ?? this.hapticFeedbackEnabled,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      locale: locale ?? this.locale,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'defaultBpm': defaultBpm,
        'defaultTimeSignature': defaultTimeSignature,
        'defaultDifficultyLevel': defaultDifficultyLevel,
        'soundEnabled': soundEnabled,
        'hapticFeedbackEnabled': hapticFeedbackEnabled,
        'notificationsEnabled': notificationsEnabled,
        'locale': locale,
        'updatedAt': dateToJson(updatedAt),
        'schemaVersion': schemaVersion,
      };

  factory UserSettings.fromJson(Map<String, dynamic> json) => UserSettings(
        defaultBpm: intFromJson(json, 'defaultBpm', fallback: 100),
        defaultTimeSignature:
            stringFromJson(json, 'defaultTimeSignature', fallback: '4/4'),
        defaultDifficultyLevel:
            intFromJson(json, 'defaultDifficultyLevel', fallback: 1),
        soundEnabled: boolFromJson(json, 'soundEnabled', fallback: true),
        hapticFeedbackEnabled:
            boolFromJson(json, 'hapticFeedbackEnabled', fallback: true),
        notificationsEnabled:
            boolFromJson(json, 'notificationsEnabled', fallback: true),
        locale: stringFromJson(json, 'locale', fallback: 'it'),
        updatedAt: dateFromJson(json['updatedAt']) ?? DateTime.now().toUtc(),
        schemaVersion: intFromJson(json, 'schemaVersion', fallback: 1),
      );
}
