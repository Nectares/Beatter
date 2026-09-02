/// Requisiti di versione pubblicati dal backend (`config/appVersion`).
///
/// Documento pubblico in lettura: va letto anche da chi non ha ancora fatto
/// login, e soprattutto da chi è bloccato fuori proprio perché la sua build
/// è troppo vecchia.
class AppVersionConfig {
  /// Versione minima ancora utilizzabile: sotto questa l'app si blocca.
  /// `null` = nessun blocco.
  final String? minSupportedVersion;

  /// Ultima versione pubblicata: sopra la installata fa comparire il
  /// dialog "aggiornamento disponibile". `null` = niente proposta.
  final String? latestVersion;

  /// Link diretti alle schede store. Servono qui (e non nel codice) perché
  /// l'id App Store cambia a pubblicazione e non vogliamo una release solo
  /// per correggerlo.
  final String? androidStoreUrl;
  final String? iosStoreUrl;

  /// Messaggio facoltativo mostrato nella schermata di blocco al posto di
  /// quello di default (es. "questa versione non parla più col server").
  final String? blockingMessage;

  /// Note di rilascio brevi mostrate nel dialog dell'aggiornamento.
  final String? releaseNotes;

  const AppVersionConfig({
    this.minSupportedVersion,
    this.latestVersion,
    this.androidStoreUrl,
    this.iosStoreUrl,
    this.blockingMessage,
    this.releaseNotes,
  });

  factory AppVersionConfig.fromJson(Map<String, dynamic> json) =>
      AppVersionConfig(
        minSupportedVersion: _text(json['minSupportedVersion']),
        latestVersion: _text(json['latestVersion']),
        androidStoreUrl: _text(json['androidStoreUrl']),
        iosStoreUrl: _text(json['iosStoreUrl']),
        blockingMessage: _text(json['blockingMessage']),
        releaseNotes: _text(json['releaseNotes']),
      );

  Map<String, dynamic> toJson() => {
        if (minSupportedVersion != null) 'minSupportedVersion': minSupportedVersion,
        if (latestVersion != null) 'latestVersion': latestVersion,
        if (androidStoreUrl != null) 'androidStoreUrl': androidStoreUrl,
        if (iosStoreUrl != null) 'iosStoreUrl': iosStoreUrl,
        if (blockingMessage != null) 'blockingMessage': blockingMessage,
        if (releaseNotes != null) 'releaseNotes': releaseNotes,
      };

  /// Stringhe vuote e valori non testuali contano come "non impostato":
  /// un campo svuotato dalla console non deve bloccare nessuno.
  static String? _text(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
