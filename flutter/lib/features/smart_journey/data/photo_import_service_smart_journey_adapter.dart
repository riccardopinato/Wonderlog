import '../../memories/data/photo_import_service.dart';
import '../../memories/domain/memory_models.dart';
import '../domain/smart_journey_photo_importer.dart';

final class PhotoImportServiceSmartJourneyAdapter
    implements SmartJourneyPhotoImporter {
  PhotoImportServiceSmartJourneyAdapter(this.service);

  final PhotoImportService service;

  @override
  Future<AlbumPhotoEntry> importPhoto({
    required String journeyId,
    required String sourceUri,
    required int displayOrder,
    required List<AlbumPhotoEntry> existingPhotos,
  }) =>
      service.importPhoto(
        journeyId: journeyId,
        sourceUri: sourceUri,
        displayOrder: displayOrder,
        existingPhotos: existingPhotos,
      );
}
