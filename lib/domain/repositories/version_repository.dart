import '../entities/app_version_config.dart';

/// Requisiti di versione pubblicati dal backend.
///
/// Restituisce `null` quando non c'è niente da far rispettare — documento
/// assente, backend locale, rete assente: in dubbio l'app parte, un errore
/// di rete non deve rendere l'app inutilizzabile.
abstract interface class VersionRepository {
  Future<AppVersionConfig?> fetchConfig();
}
