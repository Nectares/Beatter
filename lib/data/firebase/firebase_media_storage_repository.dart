import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../domain/repositories/media_storage_repository.dart';
import 'firebase_failure_mapper.dart';

class FirebaseMediaStorageRepository implements MediaStorageRepository {
  final FirebaseStorage _storage;

  FirebaseMediaStorageRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  Reference _avatarRef(String uid) => _storage.ref('users/$uid/avatar.jpg');

  @override
  Future<String> uploadAvatar(String uid, Uint8List bytes,
          {String contentType = 'image/jpeg'}) =>
      guard(() async {
        final ref = _avatarRef(uid);
        await ref.putData(bytes, SettableMetadata(contentType: contentType));
        return ref.getDownloadURL();
      });

  @override
  Future<void> deleteAvatar(String uid) => guard(() async {
        try {
          await _avatarRef(uid).delete();
        } on FirebaseException catch (e) {
          if (e.code != 'object-not-found') rethrow; // deleting twice is fine
        }
      });

  @override
  Future<String> uploadPdfExport(String uid, String fileName, Uint8List bytes) =>
      guard(() async {
        final safeName = fileName.replaceAll(RegExp(r'[^\w\-. ]'), '_');
        final ref = _storage.ref('users/$uid/exports/$safeName');
        await ref.putData(bytes, SettableMetadata(contentType: 'application/pdf'));
        return ref.getDownloadURL();
      });
}
