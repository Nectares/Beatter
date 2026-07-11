import 'dart:typed_data';

/// Binary asset storage (Cloud Storage in production).
abstract interface class MediaStorageRepository {
  /// Uploads the user's avatar and returns its download URL.
  Future<String> uploadAvatar(String uid, Uint8List bytes, {String contentType = 'image/jpeg'});

  Future<void> deleteAvatar(String uid);

  /// Stores an exported PDF (e.g. a Sheet Mode exercise) under the user's
  /// folder and returns its download URL.
  Future<String> uploadPdfExport(String uid, String fileName, Uint8List bytes);
}
