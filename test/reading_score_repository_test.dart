import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:beatter/core/di/service_locator.dart';
import 'package:beatter/services/reading_score_repository.dart';

/// Il repository dei record passa dal backend facade (qui in modalità
/// locale, come i widget test): stessi percorsi di codice della modalità
/// Firestore, storage su SharedPreferences.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ServiceLocator.configureLocal();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ReadingScoreRepository().resetForTests();
    await ReadingScoreRepository().init();
  });

  test('un esercizio mai giocato non ha record', () {
    expect(ReadingScoreRepository().recordFor('ex1'), isNull);
  });

  test('il primo punteggio positivo diventa record e sopravvive al reload',
      () async {
    final repo = ReadingScoreRepository();
    expect(await repo.submit('ex1', good: 12, strike: 5), isTrue);

    final record = repo.recordFor('ex1');
    expect(record!.good, 12);
    expect(record.strike, 5);

    // Riparte da zero (nuova sessione app): il record arriva dallo storage.
    await repo.resetForTests();
    await repo.init();
    final reloaded = repo.recordFor('ex1');
    expect(reloaded!.good, 12);
    expect(reloaded.strike, 5);
  });

  test('i record salgono in modo indipendente e mai al ribasso', () async {
    final repo = ReadingScoreRepository();
    await repo.submit('ex1', good: 12, strike: 5);

    // Sessione peggiore: nessun record, valori invariati.
    expect(await repo.submit('ex1', good: 8, strike: 3), isFalse);
    var record = repo.recordFor('ex1');
    expect(record!.good, 12);
    expect(record.strike, 5);

    // Migliora solo la strike: good resta al massimo storico.
    expect(await repo.submit('ex1', good: 10, strike: 9), isTrue);
    record = repo.recordFor('ex1');
    expect(record!.good, 12);
    expect(record.strike, 9);
  });

  test('i record sono per-esercizio', () async {
    final repo = ReadingScoreRepository();
    await repo.submit('ex1', good: 12, strike: 5);
    await repo.submit('ex2', good: 3, strike: 3);

    expect(repo.recordFor('ex1')!.good, 12);
    expect(repo.recordFor('ex2')!.good, 3);
  });
}
