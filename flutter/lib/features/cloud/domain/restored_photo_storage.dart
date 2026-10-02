import 'dart:typed_data';

final class RestoredPhotoFiles {
  const RestoredPhotoFiles({
    required this.originalPath,
    required this.thumbnailPath,
    required this.fileSize,
    required this.width,
    required this.height,
  });

  final String originalPath;
  final String thumbnailPath;
  final int fileSize;
  final int width;
  final int height;
}

abstract interface class RestoredPhotoStorage {
  Future<RestoredPhotoFiles> save({
    required String journeyId,
    required String photoId,
    required Uint8List bytes,
    String? fileName,
    String? mimeType,
  });
}
