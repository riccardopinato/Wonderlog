import '../../memories/domain/memory_models.dart';

abstract interface class SmartJourneyPhotoImporter {
  Future<AlbumPhotoEntry> importPhoto({
    required String journeyId,
    required String sourceUri,
    required int displayOrder,
    required List<AlbumPhotoEntry> existingPhotos,
  });
}

final class SmartJourneyPhotoImportUnavailable
    implements SmartJourneyPhotoImporter {
  const SmartJourneyPhotoImportUnavailable();

  @override
  Future<AlbumPhotoEntry> importPhoto({
    required String journeyId,
    required String sourceUri,
    required int displayOrder,
    required List<AlbumPhotoEntry> existingPhotos,
  }) {
    throw UnsupportedError(
      'Photo import adapter is not configured for this platform build.',
    );
  }
}
