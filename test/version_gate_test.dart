// Il gate delle versioni: blocco duro sotto la minima supportata, proposta
// (saltabile) quando c'è solo una versione più nuova.
//
// La decisione è pura e si prova da sola; il resto è il comportamento che
// conta davvero — che il blocco copra anche una sessione già aperta, e che
// "salta questa versione" resti saltata fino alla release dopo.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beatter/core/version/app_version.dart';
import 'package:beatter/core/version/store_launcher.dart';
import 'package:beatter/domain/entities/app_version_config.dart';
import 'package:beatter/domain/repositories/version_repository.dart';
import 'package:beatter/features/update/presentation/pages/out_of_date_page.dart';
import 'package:beatter/features/update/presentation/version_gate.dart';
import 'package:beatter/theme/app_theme.dart';

class _FakeVersionRepository implements VersionRepository {
  _FakeVersionRepository(this.config);

  final AppVersionConfig? config;
  int calls = 0;

  @override
  Future<AppVersionConfig?> fetchConfig() async {
    calls++;
    return config;
  }
}

/// Monta il gate come lo monta l'app: nel `builder`, sopra il Navigator.
Future<_GateHarness> _pumpGate(
  WidgetTester tester, {
  required String installed,
  AppVersionConfig? config,
}) async {
  final navigatorKey = GlobalKey<NavigatorState>();
  final repository = _FakeVersionRepository(config);
  final opened = <String>[];

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      navigatorKey: navigatorKey,
      home: const Scaffold(body: Center(child: Text('sessione aperta'))),
      builder: (context, child) => VersionGate(
        navigatorKey: navigatorKey,
        repository: repository,
        readInstalledVersion: () async => installed,
        openStore: (url) async => opened.add(url),
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  return _GateHarness(repository: repository, openedUrls: opened);
}

class _GateHarness {
  _GateHarness({required this.repository, required this.openedUrls});

  final _FakeVersionRepository repository;
  final List<String> openedUrls;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('compareVersions', () {
    test('ordina per segmento numerico', () {
      expect(compareVersions('1.0.0', '1.0.1'), lessThan(0));
      expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
      expect(compareVersions('1.2.3', '1.2.3'), 0);
    });

    test('i segmenti mancanti valgono zero', () {
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('1.2', '1.2.1'), lessThan(0));
    });

    test('build number e suffissi non contano', () {
      expect(compareVersions('1.0.0+7', '1.0.0+99'), 0);
      expect(compareVersions('1.0.0-beta', '1.0.0'), 0);
    });

    test('tollera versioni malformate invece di esplodere', () {
      expect(compareVersions('v1.2.0', '1.2.0'), 0);
      expect(compareVersions('', '0.0.0'), 0);
      expect(compareVersions('boh', '1.0.0'), lessThan(0));
    });
  });

  group('evaluateUpdate', () {
    const config = AppVersionConfig(
      minSupportedVersion: '1.2.0',
      latestVersion: '1.5.0',
    );

    test('sotto la minima supportata blocca', () {
      expect(
        evaluateUpdate(installedVersion: '1.1.9', config: config),
        UpdateRequirement.blocking,
      );
    });

    test('esattamente alla minima passa', () {
      expect(
        evaluateUpdate(installedVersion: '1.2.0', config: config),
        UpdateRequirement.optional,
      );
    });

    test('sotto l\'ultima pubblicata propone', () {
      expect(
        evaluateUpdate(installedVersion: '1.4.0', config: config),
        UpdateRequirement.optional,
      );
    });

    test('aggiornata (o oltre) non chiede niente', () {
      expect(
        evaluateUpdate(installedVersion: '1.5.0', config: config),
        UpdateRequirement.none,
      );
      expect(
        evaluateUpdate(installedVersion: '2.0.0', config: config),
        UpdateRequirement.none,
      );
    });

    test('la versione saltata resta saltata, ma solo quella', () {
      expect(
        evaluateUpdate(
          installedVersion: '1.4.0',
          config: config,
          skippedVersion: '1.5.0',
        ),
        UpdateRequirement.none,
      );
      expect(
        evaluateUpdate(
          installedVersion: '1.4.0',
          config: const AppVersionConfig(
            minSupportedVersion: '1.2.0',
            latestVersion: '1.6.0',
          ),
          skippedVersion: '1.5.0',
        ),
        UpdateRequirement.optional,
        reason: 'una release più nuova torna a chiedere',
      );
    });

    test('saltare non salva da un blocco', () {
      expect(
        evaluateUpdate(
          installedVersion: '1.0.0',
          config: config,
          skippedVersion: '1.5.0',
        ),
        UpdateRequirement.blocking,
      );
    });

    test('senza configurazione non si blocca mai', () {
      expect(
        evaluateUpdate(installedVersion: '0.1.0'),
        UpdateRequirement.none,
      );
    });
  });

  group('StoreLauncher.urlFor', () {
    test('usa gli URL del documento quando ci sono', () {
      const config = AppVersionConfig(
        androidStoreUrl: 'https://play.example/beatter',
        iosStoreUrl: 'https://apple.example/beatter',
      );

      expect(
        StoreLauncher.urlFor(platform: TargetPlatform.android, config: config),
        'https://play.example/beatter',
      );
      expect(
        StoreLauncher.urlFor(platform: TargetPlatform.iOS, config: config),
        'https://apple.example/beatter',
      );
    });

    test('senza documento ripiega sullo store della piattaforma', () {
      expect(
        StoreLauncher.urlFor(platform: TargetPlatform.android),
        contains('com.nectares.beatter'),
      );
      expect(
        StoreLauncher.urlFor(platform: TargetPlatform.iOS),
        contains('apple.com'),
      );
    });
  });

  group('VersionGate', () {
    testWidgets('una build fuori supporto vede solo la schermata di blocco',
        (tester) async {
      final harness = await _pumpGate(
        tester,
        installed: '1.0.0',
        config: const AppVersionConfig(
          minSupportedVersion: '1.2.0',
          latestVersion: '1.5.0',
        ),
      );

      expect(find.byType(OutOfDatePage), findsOneWidget);
      expect(find.text('sessione aperta'), findsNothing,
          reason: 'anche con la sessione già aperta si vede solo il blocco');
      expect(find.text('Aggiorna Beatter'), findsOneWidget);

      await tester.tap(find.text('Aggiorna l\'app'));
      await tester.pumpAndSettle();
      expect(harness.openedUrls, hasLength(1));
    });

    testWidgets('il messaggio di blocco del documento vince sul default',
        (tester) async {
      await _pumpGate(
        tester,
        installed: '1.0.0',
        config: const AppVersionConfig(
          minSupportedVersion: '1.2.0',
          blockingMessage: 'Il server non parla più con questa versione.',
        ),
      );

      expect(
        find.text('Il server non parla più con questa versione.'),
        findsOneWidget,
      );
      expect(find.textContaining('minima richiesta 1.2.0'), findsOneWidget);
    });

    testWidgets('una versione nuova propone il dialog, senza bloccare',
        (tester) async {
      await _pumpGate(
        tester,
        installed: '1.4.0',
        config: const AppVersionConfig(
          minSupportedVersion: '1.0.0',
          latestVersion: '1.5.0',
          releaseNotes: 'Accenti casuali nel Flow Mode.',
        ),
      );

      expect(find.text('Nuova versione disponibile'), findsOneWidget);
      expect(find.text('Beatter 1.5.0 è disponibile sullo store.'),
          findsOneWidget);
      expect(find.text('Accenti casuali nel Flow Mode.'), findsOneWidget);
      expect(find.byType(OutOfDatePage), findsNothing);

      await tester.tap(find.text('Più tardi'));
      await tester.pumpAndSettle();
      expect(find.text('sessione aperta'), findsOneWidget);
    });

    testWidgets('"salta questa versione" la ricorda e non ripropone',
        (tester) async {
      const config = AppVersionConfig(
        minSupportedVersion: '1.0.0',
        latestVersion: '1.5.0',
      );

      await _pumpGate(tester, installed: '1.4.0', config: config);
      await tester.tap(find.text('Salta questa versione'));
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(VersionGate.skippedVersionKey), '1.5.0');

      // Riavvio: stessa configurazione, nessun dialog.
      await _pumpGate(tester, installed: '1.4.0', config: config);
      expect(find.text('Nuova versione disponibile'), findsNothing);
      expect(find.text('sessione aperta'), findsOneWidget);
    });

    testWidgets('dallo store: il pulsante Aggiorna apre il link giusto',
        (tester) async {
      final harness = await _pumpGate(
        tester,
        installed: '1.4.0',
        config: const AppVersionConfig(
          latestVersion: '1.5.0',
          androidStoreUrl: 'https://play.example/beatter',
          iosStoreUrl: 'https://apple.example/beatter',
        ),
      );

      await tester.tap(find.text('Aggiorna'));
      await tester.pumpAndSettle();

      expect(harness.openedUrls, ['https://play.example/beatter']);
    });

    testWidgets('backend muto: l\'app parte normalmente', (tester) async {
      final harness = await _pumpGate(tester, installed: '1.0.0');

      expect(harness.repository.calls, 1);
      expect(find.byType(OutOfDatePage), findsNothing);
      expect(find.text('sessione aperta'), findsOneWidget);
    });
  });
}
