import '../../memories/domain/memory_models.dart';
import 'capture_models.dart';

abstract interface class CaptureMediaPort {
  Future<AlbumPhotoEntry?> importPhoto({
    required String journeyId,
    required CaptureIncomingItem item,
    required int displayOrder,
    required List<AlbumPhotoEntry> existingPhotos,
  });

  Future<MemoryAttachment?> importKeepsake({
    required String memoryId,
    required CaptureIncomingItem item,
  });
}

final class UnsupportedCaptureMediaPort implements CaptureMediaPort {
  const UnsupportedCaptureMediaPort();

  @override
  Future<AlbumPhotoEntry?> importPhoto({
    required String journeyId,
    required CaptureIncomingItem item,
    required int displayOrder,
    required List<AlbumPhotoEntry> existingPhotos,
  }) async =>
      null;

  @override
  Future<MemoryAttachment?> importKeepsake({
    required String memoryId,
    required CaptureIncomingItem item,
  }) async =>
      null;
}
