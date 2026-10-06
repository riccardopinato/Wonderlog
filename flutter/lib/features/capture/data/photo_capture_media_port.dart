import '../../memories/data/photo_import_service.dart';
import '../../memories/domain/memory_models.dart';
import '../domain/capture_media_port.dart';
import '../domain/capture_models.dart';

final class PhotoCaptureMediaPort implements CaptureMediaPort {
  PhotoCaptureMediaPort({
    required this.photoImportService,
  });

  final PhotoImportService photoImportService;
  @override
  Future<AlbumPhotoEntry?> importPhoto({
    required String journeyId,
    required CaptureIncomingItem item,
    required int displayOrder,
    required List<AlbumPhotoEntry> existingPhotos,
  }) async {
    final uri = item.uri?.trim();
    if (uri == null || uri.isEmpty) return null;
    return photoImportService.importPhoto(
      journeyId: journeyId,
      sourceUri: uri,
      displayOrder: displayOrder,
      existingPhotos: existingPhotos,
      fileName: item.title,
      mimeType: item.mimeType,
      latitude: item.location?.latitude,
      longitude: item.location?.longitude,
      locationName: item.location?.label ?? '',
    );
  }

  @override
  Future<MemoryAttachment?> importKeepsake({
    required String memoryId,
    required CaptureIncomingItem item,
  }) async {
    final uri = item.uri?.trim();
    if (uri == null || uri.isEmpty) return null;
    return photoImportService.importKeepsake(
      memoryId: memoryId,
      sourceUri: uri,
      existingAttachments: const [],
      fileName: item.title,
      mimeType: item.mimeType,
    );
  }
}
