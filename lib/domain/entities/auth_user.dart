/// The authenticated identity, as exposed to the app.
///
/// This is a thin, immutable projection of the Firebase `User` (or the local
/// mock session) so nothing above the data layer imports firebase_auth.
class AuthUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final bool isAnonymous;

  /// Linked provider ids, e.g. `google.com`, `apple.com`, `password`.
  final List<String> providerIds;

  const AuthUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.isAnonymous = false,
    this.providerIds = const [],
  });

  bool get hasGoogle => providerIds.contains('google.com');
  bool get hasApple => providerIds.contains('apple.com');

  AuthUser copyWith({
    String? email,
    String? displayName,
    String? photoUrl,
    bool? isAnonymous,
    List<String>? providerIds,
  }) {
    return AuthUser(
      uid: uid,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      providerIds: providerIds ?? this.providerIds,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthUser &&
      other.uid == uid &&
      other.email == email &&
      other.displayName == displayName &&
      other.photoUrl == photoUrl &&
      other.isAnonymous == isAnonymous;

  @override
  int get hashCode => Object.hash(uid, email, displayName, photoUrl, isAnonymous);
}
