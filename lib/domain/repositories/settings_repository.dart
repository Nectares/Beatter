import '../entities/user_settings.dart';

/// Per-user preferences. Offline-first: reads serve the local cache
/// instantly, writes sync in the background.
abstract interface class SettingsRepository {
  /// Emits current settings (defaults if none saved yet), then every change —
  /// including changes made on other devices.
  Stream<UserSettings> watchSettings(String uid);

  Future<UserSettings> fetchSettings(String uid);

  Future<void> saveSettings(String uid, UserSettings settings);
}
