import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/di/service_locator.dart';
import '../../../core/version/app_version.dart';
import '../../../core/version/store_launcher.dart';
import '../../../domain/entities/app_version_config.dart';
import '../../../domain/repositories/version_repository.dart';
import 'pages/out_of_date_page.dart';
import 'widgets/update_available_dialog.dart';

/// Confronta la versione installata con i requisiti pubblicati su Firebase
/// e decide cosa può vedere l'utente.
///
/// Sta nel `builder` di [MaterialApp], sopra il Navigator: così il blocco
/// copre *qualunque* schermata, comprese quelle raggiunte dopo il login —
/// una sessione già aperta non è una scorciatoia per usare una build fuori
/// supporto. Finché il controllo non ha risposto l'app parte normalmente:
/// un errore di rete non deve trasformarsi in una schermata di blocco.
class VersionGate extends StatefulWidget {
  const VersionGate({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.repository,
    this.readInstalledVersion,
    this.openStore,
  });

  /// Chiave in preferenze dell'ultima versione saltata dall'utente.
  static const String skippedVersionKey = 'update.skipped_version';

  /// Serve per aprire il dialog: il contesto del `builder` sta sopra il
  /// Navigator e non ne troverebbe uno.
  final GlobalKey<NavigatorState> navigatorKey;

  final Widget child;

  /// Iniettabili nei test; in produzione sono Firebase, package_info e lo
  /// store di sistema.
  final VersionRepository? repository;
  final Future<String> Function()? readInstalledVersion;
  final Future<void> Function(String url)? openStore;

  @override
  State<VersionGate> createState() => _VersionGateState();
}

class _VersionGateState extends State<VersionGate> {
  UpdateRequirement _requirement = UpdateRequirement.none;
  AppVersionConfig? _config;
  String? _installedVersion;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    UpdateRequirement requirement = UpdateRequirement.none;
    AppVersionConfig? config;
    String? installed;

    try {
      installed = await (widget.readInstalledVersion ?? _packageVersion)();
      config = await (widget.repository ?? ServiceLocator.get<VersionRepository>())
          .fetchConfig();
      requirement = evaluateUpdate(
        installedVersion: installed,
        config: config,
        skippedVersion: await _skippedVersion(),
      );
    } catch (_) {
      // Versione illeggibile, backend irraggiungibile, preferenze non
      // disponibili: in dubbio si passa. Meglio un aggiornamento mancato
      // che un'app che non si apre.
      requirement = UpdateRequirement.none;
    }

    if (!mounted) return;
    setState(() {
      _requirement = requirement;
      _config = config;
      _installedVersion = installed;
    });

    if (requirement == UpdateRequirement.optional) {
      await _proposeUpdate();
    }
  }

  static Future<String> _packageVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  Future<String?> _skippedVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(VersionGate.skippedVersionKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> _proposeUpdate() async {
    // Un frame di respiro: il dialog deve trovare il Navigator già montato.
    await Future<void>.delayed(Duration.zero);
    final navigatorContext = widget.navigatorKey.currentContext;
    if (!mounted || navigatorContext == null || !navigatorContext.mounted) {
      return;
    }

    final choice =
        await UpdateAvailableDialog.show(navigatorContext, config: _config);
    switch (choice) {
      case UpdateChoice.update:
        await _openStore();
      case UpdateChoice.skip:
        final String? latest = _config?.latestVersion;
        if (latest != null) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(VersionGate.skippedVersionKey, latest);
          } catch (_) {
            // Niente preferenze: la proposta tornerà al prossimo avvio.
          }
        }
      case UpdateChoice.later:
      case null:
        break;
    }
  }

  Future<void> _openStore() async {
    final url = StoreLauncher.urlFor(
      platform: Theme.of(context).platform,
      config: _config,
    );
    await (widget.openStore ?? StoreLauncher.open)(url);
  }

  @override
  Widget build(BuildContext context) {
    if (_requirement == UpdateRequirement.blocking) {
      return OutOfDatePage(
        installedVersion: _installedVersion,
        config: _config,
        onUpdate: _openStore,
        onRetry: _check,
      );
    }
    return widget.child;
  }
}
