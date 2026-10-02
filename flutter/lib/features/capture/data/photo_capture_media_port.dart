import 'package:uuid/uuid.dart';

import '../../memories/data/photo_import_service.dart';
import '../../memories/domain/memory_models.dart';
import '../domain/capture_media_port.dart';
import '../domain/capture_models.dart';

final class PhotoCaptureMediaPort implements CaptureMediaPort {
  PhotoCaptureMediaPort({
    required this.photoImportService,
  });

  final PhotoImportService photoImportService;
  final Uuid _uuid = const Uuid();

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
    return MemoryAttachment(
      id: 'attachment_' + _uuid.v4(),
      memoryId: memoryId,
      localUri: uri,
      originalName: item.title,
      mimeType: item.mimeType ?? 'application/octet-stream',
      attachmentType: _attachmentType(item),
      createdAt: DateTime.now().toUtc(),
      syncStatus: 'LOCAL_ONLY',
    );
  }

  String _attachmentType(CaptureIncomingItem item) {
    final mime = item.mimeType?.toLowerCase() ?? '';
    if (mime == 'application/pdf') return 'DOCUMENT';
    if (mime.startsWith('image/')) return 'SCREENSHOT';
    return 'OTHER';
  }
}
