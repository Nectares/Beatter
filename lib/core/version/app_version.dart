/// Confronto di versioni e decisione sull'aggiornamento.
///
/// Tutto puro e senza Flutter: il gate (che invece parla con Firebase, con
/// il pacchetto installato e con lo store) si limita a chiamare
/// [evaluateUpdate] con i tre dati che ha raccolto.
library;

import '../../domain/entities/app_version_config.dart';

/// Cosa deve fare l'app rispetto alla versione installata.
enum UpdateRequirement {
  /// Versione a posto, o nessuna configurazione leggibile: si prosegue.
  none,

  /// C'è una versione più nuova, ma questa funziona ancora: si propone
  /// l'aggiornamento e si può rimandare.
  optional,

  /// Versione sotto la minima supportata: l'app resta inutilizzabile
  /// finché non si aggiorna.
  blocking,
}

/// Confronta due versioni tipo `1.2.3` (o `1.2.3+7`, `v1.2`).
///
/// Restituisce < 0 se [a] precede [b], 0 se equivalgono, > 0 altrimenti.
/// I segmenti mancanti valgono 0 (`1.2` == `1.2.0`) e tutto ciò che segue
/// `+` o `-` viene ignorato: il build number cambia a ogni caricamento
/// sullo store e non dice niente sulla compatibilità.
int compareVersions(String a, String b) {
  final segmentsA = _segments(a);
  final segmentsB = _segments(b);
  final int length = segmentsA.length > segmentsB.length
      ? segmentsA.length
      : segmentsB.length;

  for (int i = 0; i < length; i++) {
    final int left = i < segmentsA.length ? segmentsA[i] : 0;
    final int right = i < segmentsB.length ? segmentsB[i] : 0;
    if (left != right) return left < right ? -1 : 1;
  }
  return 0;
}

List<int> _segments(String version) {
  final String core = version.trim().split('+').first.split('-').first;
  final segments = <int>[];
  for (final part in core.split('.')) {
    // Tollerante: `v1`, spazi, spazzatura → il segmento vale 0 invece di
    // far fallire il confronto e bloccare l'app per un dato malformato.
    final digits = RegExp(r'\d+').firstMatch(part)?.group(0);
    segments.add(digits == null ? 0 : int.parse(digits));
  }
  return segments;
}

/// Decide cosa mostrare all'avvio.
///
/// [installedVersion] è la versione del pacchetto installato, [config]
/// quella che arriva da Firebase (null quando non è leggibile: offline, in
/// modalità locale o documento assente) e [skippedVersion] l'ultima
/// versione che l'utente ha scelto di saltare.
///
/// In dubbio non si blocca mai: senza configurazione l'app parte, perché
/// un errore di rete non deve trasformarsi in un'app inutilizzabile.
UpdateRequirement evaluateUpdate({
  required String installedVersion,
  AppVersionConfig? config,
  String? skippedVersion,
}) {
  if (config == null) return UpdateRequirement.none;

  final String? minSupported = config.minSupportedVersion;
  if (minSupported != null &&
      compareVersions(installedVersion, minSupported) < 0) {
    return UpdateRequirement.blocking;
  }

  final String? latest = config.latestVersion;
  if (latest == null || compareVersions(installedVersion, latest) >= 0) {
    return UpdateRequirement.none;
  }

  // "Salta questa versione" vale finché lo store non ne pubblica un'altra.
  if (skippedVersion != null && compareVersions(skippedVersion, latest) >= 0) {
    return UpdateRequirement.none;
  }
  return UpdateRequirement.optional;
}
