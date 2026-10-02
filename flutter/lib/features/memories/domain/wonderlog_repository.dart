import '../../journeys/domain/journey.dart';
import '../../journeys/domain/journey_repository.dart';
import 'memory_models.dart';

abstract interface class WonderlogRepository implements JourneyRepository {
  @override
  Stream<List<Journey>> watchJourneys();

  Stream<Journey?> watchJourney(String id);
  Stream<List<MemoryEntry>> watchMemories(String journeyId);
  Stream<List<MemoryEntry>> watchAllMemories();
  Stream<MemoryWithPhotos?> watchMemory(String memoryId);
  Stream<List<AlbumPhotoEntry>> watchAlbum(String journeyId);
  Stream<List<AlbumPhotoEntry>> watchAllPhotos();
  Stream<List<MemoryAttachment>> watchAttachments(String memoryId);

  @override
  Future<Journey> createJourney({
    required String title,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    String country = '',
    String description = '',
  });

  Future<void> saveJourney(Journey journey);
  Future<void> saveMemory(MemoryEntry memory);
  Future<void> deleteMemory(String memoryId);
  Future<void> savePhoto(AlbumPhotoEntry photo);
  Future<void> deletePhoto(String photoId);
  Future<void> linkPhotoToMemory({
    required String memoryId,
    required String photoId,
    required int displayOrder,
    required bool isHero,
  });
  Future<void> replaceMemoryPhotoLinks({
    required String memoryId,
    required List<String> photoIds,
  });
  Future<void> saveAttachment(MemoryAttachment attachment);
  Future<void> deleteAttachment(String attachmentId);
}
