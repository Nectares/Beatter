import 'package:cloud_functions/cloud_functions.dart';

import '../../domain/services/account_deletion_service.dart';
import 'firebase_failure_mapper.dart';

/// Production [AccountDeletionService]: invokes the `deleteAccount` callable
/// Cloud Function. The function runs with the Admin SDK and deletes the
/// caller's Firestore data, Storage files and Auth user (in that order),
/// taking the uid from the verified auth context — the client only triggers
/// it, never performs the deletion itself.
///
/// Pinned to `europe-west4`, the project's European region (matching the
/// function's deployed region); a mismatch would make the SDK call a
/// non-existent endpoint.
class FunctionsAccountDeletionService implements AccountDeletionService {
  static const String region = 'europe-west4';

  final FirebaseFunctions _functions;

  FunctionsAccountDeletionService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: region);

  @override
  Future<void> deleteAccount() => guard(() async {
        await _functions.httpsCallable('deleteAccount').call<void>();
      });
}
