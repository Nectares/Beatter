import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_version_config.dart';
import '../../domain/repositories/version_repository.dart';
import 'firestore_paths.dart';

/// Legge `config/appVersion`, il documento pubblico che dice quale build è
/// ancora supportata e qual è l'ultima pubblicata.
///
/// Nessun `guard`/rilancio come negli altri repository: qui un errore vale
/// "nessuna configurazione" e basta. Il gate che la usa gira all'avvio, e
/// un timeout o una regola cambiata non devono impedire di aprire l'app.
class FirestoreVersionRepository implements VersionRepository {
  final FirebaseFirestore _db;
  final Duration timeout;

  FirestoreVersionRepository({
    FirebaseFirestore? firestore,
    this.timeout = const Duration(seconds: 5),
  }) : _db = firestore ?? FirebaseFirestore.instance;

  @override
  Future<AppVersionConfig?> fetchConfig() async {
    try {
      final snapshot =
          await _db.doc(FirestorePaths.appVersionConfig).get().timeout(timeout);
      final data = snapshot.data();
      if (data == null) return null;
      return AppVersionConfig.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
