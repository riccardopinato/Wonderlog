import 'dart:typed_data';

import '../../../core/media/media_asset_backend.dart';
import '../../../core/media/media_asset_reference.dart';
import '../domain/restored_photo_storage.dart';

final class MediaAssetRestoredPhotoStorage implements RestoredPhotoStorage {
  const MediaAssetRestoredPhotoStorage(this.mediaStore);

  final MediaAssetStore mediaStore;

  @override
  Future<RestoredPhotoFiles> save({
    required String journeyId,
    required String photoId,
    required Uint8List bytes,
    String? fileName,
    String? mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw StateError('Restored photo is empty.');
    }

    final assetId = await mediaStore.putOriginal(
      bytes,
      mimeType: mimeType,
    );
    final reference = MediaAssetReference.encode(assetId);

    return RestoredPhotoFiles(
      originalPath: reference,
      thumbnailPath: reference,
      fileSize: bytes.length,
      width: 0,
      height: 0,
    );
  }
}
