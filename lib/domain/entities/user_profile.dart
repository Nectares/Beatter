import '../../core/utils/json_codecs.dart';

enum UserProfileRole { user, admin }

/// Public-facing user document (`users/{uid}`).
///
/// Kept intentionally small and denormalization-friendly: `displayName` and
/// `photoUrl` are copied into leaderboard entries by Cloud Functions, and
/// `username` reserves a handle for future social features (uniqueness is
/// enforced through the `usernames/{handle}` collection).
class UserProfile {
  static const int currentSchemaVersion = 1;

  final String uid;
  final String? email;
  final String displayName;
  final String? photoUrl;
  final String? username;
  final String? bio;
  final UserProfileRole role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int schemaVersion;

  const UserProfile({
    required this.uid,
    this.email,
    required this.displayName,
    this.photoUrl,
    this.username,
    this.bio,
    this.role = UserProfileRole.user,
    required this.createdAt,
    required this.updatedAt,
    this.schemaVersion = currentSchemaVersion,
  });

  bool get isAdmin => role == UserProfileRole.admin;

  UserProfile copyWith({
    String? email,
    String? displayName,
    String? photoUrl,
    String? username,
    String? bio,
    UserProfileRole? role,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      username: username ?? this.username,
      bio: bio ?? this.bio,
      role: role ?? this.role,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      schemaVersion: schemaVersion,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'username': username,
        'bio': bio,
        'role': role.name,
        'createdAt': dateToJson(createdAt),
        'updatedAt': dateToJson(updatedAt),
        'schemaVersion': schemaVersion,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now().toUtc();
    return UserProfile(
      uid: stringFromJson(json, 'uid'),
      email: json['email'] as String?,
      displayName: stringFromJson(json, 'displayName', fallback: 'Musicista'),
      photoUrl: json['photoUrl'] as String?,
      username: json['username'] as String?,
      bio: json['bio'] as String?,
      role: json['role'] == UserProfileRole.admin.name
          ? UserProfileRole.admin
          : UserProfileRole.user,
      createdAt: dateFromJson(json['createdAt']) ?? now,
      updatedAt: dateFromJson(json['updatedAt']) ?? now,
      schemaVersion: intFromJson(json, 'schemaVersion', fallback: 1),
    );
  }
}
