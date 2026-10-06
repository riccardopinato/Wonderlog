import '../../journeys/domain/journey.dart';
import '../../journeys/domain/journey_repository.dart';
import 'memory_models.dart';

abstract interface class WonderlogRepository implements JourneyRepository {
  @override
  Stream<List<Journey>> watchJourneys();

  Stream<Journey?> watchJourney(String id);
  Stream<List<Journey>> watchArchivedJourneys();
  Stream<List<MemoryEntry>> watchMemories(String journeyId);
  Stream<List<MemoryEntry>> watchAllMemories();
  Stream<List<MemoryEntry>> watchUnassignedMemories();
  Stream<List<MemoryWithPhotos>> watchMemoriesWithPhotos(String journeyId);
  Stream<List<MemoryWithPhotos>> watchAllMemoriesWithPhotos();
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
  Future<void> setJourneyArchived(String journeyId, bool archived);
  Future<JourneyDeletionImpact> getJourneyDeletionImpact(String journeyId);
  Future<void> deleteJourney(String journeyId);
  Future<void> saveMemory(MemoryEntry memory);
  Future<void> moveMemoryToJourney(String memoryId, String? journeyId);
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
  Future<void> unlinkPhotoFromMemory({
    required String memoryId,
    required String photoId,
  });
  Future<void> setJourneyCoverPhoto({
    required String journeyId,
    String? photoId,
  });
  Future<Set<String>> referencedMediaUris();
  Future<void> saveAttachment(MemoryAttachment attachment);
  Future<void> deleteAttachment(String attachmentId);
}
