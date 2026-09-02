import '../../domain/entities/app_version_config.dart';
import '../../domain/repositories/version_repository.dart';

/// In modalità locale non c'è nessuno che pubblichi i requisiti di
/// versione: niente blocco e niente proposta di aggiornamento.
class LocalVersionRepository implements VersionRepository {
  const LocalVersionRepository();

  @override
  Future<AppVersionConfig?> fetchConfig() async => null;
}
