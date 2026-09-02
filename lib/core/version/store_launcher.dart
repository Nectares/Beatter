import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/app_version_config.dart';

/// Dove mandare l'utente ad aggiornare.
///
/// Gli URL veri arrivano dal documento di configurazione: l'id numerico
/// dell'App Store esiste solo dopo la prima pubblicazione, e non vogliamo
/// una release solo per scriverlo nel codice. Quelli qui sotto sono il
/// ripiego per quando il documento non li porta.
abstract final class StoreLauncher {
  static const String androidPackageId = 'com.nectares.beatter';

  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=$androidPackageId';

  /// Senza id App Store si ripiega sulla ricerca per nome: meglio della
  /// home dello store, e comunque un caso che sparisce appena il
  /// documento di configurazione porta `iosStoreUrl`.
  static const String appStoreSearchUrl =
      'https://apps.apple.com/search?term=beatter';

  /// Puro e testabile: sceglie l'URL per la piattaforma corrente.
  static String urlFor({
    required TargetPlatform platform,
    AppVersionConfig? config,
  }) {
    final bool apple =
        platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
    if (apple) return config?.iosStoreUrl ?? appStoreSearchUrl;
    return config?.androidStoreUrl ?? playStoreUrl;
  }

  /// Apre la scheda store fuori dall'app. `false` se il sistema non sa
  /// gestire l'URL (chiamante libero di mostrare un errore).
  static Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }
}
