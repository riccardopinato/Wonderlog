import '../../cloud/domain/cloud_models.dart';
import '../../cloud/domain/cloud_sync_repository.dart';
import '../../journeys/domain/journey.dart';
import '../domain/memory_models.dart';
import '../domain/wonderlog_repository.dart';

final class CloudAwareWonderlogRepository implements WonderlogRepository {
  CloudAwareWonderlogRepository({
    required this.delegate,
    required this.cloudSyncRepository,
  });

  final WonderlogRepository delegate;
  final CloudSyncRepository cloudSyncRepository;

  @override
  Stream<List<Journey>> watchJourneys() => delegate.watchJourneys();

  @override
  Stream<Journey?> watchJourney(String id) => delegate.watchJourney(id);

  @override
  Stream<List<Journey>> watchArchivedJourneys() =>
      delegate.watchArchivedJourneys();

  @override
  Stream<List<MemoryEntry>> watchMemories(String journeyId) =>
      delegate.watchMemories(journeyId);

  @override
  Stream<List<MemoryEntry>> watchAllMemories() =>
      delegate.watchAllMemories();

  @override
  Stream<List<MemoryEntry>> watchUnassignedMemories() =>
      delegate.watchUnassignedMemories();

  @override
  Stream<List<MemoryWithPhotos>> watchMemoriesWithPhotos(String journeyId) =>
      delegate.watchMemoriesWithPhotos(journeyId);

  @override
  Stream<List<MemoryWithPhotos>> watchAllMemoriesWithPhotos() =>
      delegate.watchAllMemoriesWithPhotos();

  @override
  Stream<MemoryWithPhotos?> watchMemory(String memoryId) =>
      delegate.watchMemory(memoryId);

  @override
  Stream<List<AlbumPhotoEntry>> watchAlbum(String journeyId) =>
      delegate.watchAlbum(journeyId);

  @override
  Stream<List<AlbumPhotoEntry>> watchAllPhotos() =>
      delegate.watchAllPhotos();

  @override
  Stream<List<MemoryAttachment>> watchAttachments(String memoryId) =>
      delegate.watchAttachments(memoryId);

  @override
  Future<Journey> createJourney({
    required String title,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    String country = '',
    String description = '',
  }) async {
    final journey = await delegate.createJourney(
      title: title,
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      country: country,
      description: description,
    );
    await cloudSyncRepository.enqueueJourney(journey.id);
    return journey;
  }

  @override
  Future<void> saveJourney(Journey journey) async {
    await delegate.saveJourney(journey);
    await cloudSyncRepository.enqueueJourney(journey.id);
  }

  @override
  Future<void> setJourneyArchived(String journeyId, bool archived) async {
    await delegate.setJourneyArchived(journeyId, archived);
    await cloudSyncRepository.enqueueJourney(journeyId);
  }

  @override
  Future<JourneyDeletionImpact> getJourneyDeletionImpact(String journeyId) =>
      delegate.getJourneyDeletionImpact(journeyId);

  @override
  Future<void> deleteJourney(String journeyId) async {
    final memories = await delegate.watchMemories(journeyId).first;
    final photos = await delegate.watchAlbum(journeyId).first;
    await delegate.deleteJourney(journeyId);

    for (final memory in memories) {
      await cloudSyncRepository.enqueueDelete(
        SyncEntityType.memory,
        memory.id,
      );
    }
    for (final photo in photos) {
      await cloudSyncRepository.enqueueDelete(
        SyncEntityType.albumPhoto,
        photo.id,
      );
    }
    await cloudSyncRepository.enqueueDelete(
      SyncEntityType.journey,
      journeyId,
    );
  }

  @override
  Future<void> saveMemory(MemoryEntry memory) async {
    await delegate.saveMemory(memory);
    if (memory.journeyId != null) {
      await cloudSyncRepository.enqueueMemory(memory.id);
    }
  }

  @override
  Future<void> moveMemoryToJourney(
    String memoryId,
    String? journeyId,
  ) async {
    await delegate.moveMemoryToJourney(memoryId, journeyId);
    if (journeyId == null) {
      await cloudSyncRepository.enqueueDelete(
        SyncEntityType.memory,
        memoryId,
      );
    } else {
      await cloudSyncRepository.enqueueMemory(memoryId);
    }
  }

  @override
  Future<void> deleteMemory(String memoryId) async {
    await delegate.deleteMemory(memoryId);
    await cloudSyncRepository.enqueueDelete(
      SyncEntityType.memory,
      memoryId,
    );
  }

  @override
  Future<void> savePhoto(AlbumPhotoEntry photo) async {
    await delegate.savePhoto(photo);
    await cloudSyncRepository.enqueuePhoto(photo.id);
  }

  @override
  Future<void> deletePhoto(String photoId) async {
    await delegate.deletePhoto(photoId);
    await cloudSyncRepository.enqueueDelete(
      SyncEntityType.albumPhoto,
      photoId,
    );
  }

  @override
  Future<void> linkPhotoToMemory({
    required String memoryId,
    required String photoId,
    required int displayOrder,
    required bool isHero,
  }) async {
    await delegate.linkPhotoToMemory(
      memoryId: memoryId,
      photoId: photoId,
      displayOrder: displayOrder,
      isHero: isHero,
    );
    await cloudSyncRepository.enqueueMemory(memoryId);
  }

  @override
  Future<void> replaceMemoryPhotoLinks({
    required String memoryId,
    required List<String> photoIds,
  }) async {
    await delegate.replaceMemoryPhotoLinks(
      memoryId: memoryId,
      photoIds: photoIds,
    );
    await cloudSyncRepository.enqueueMemory(memoryId);
  }

  @override
  Future<void> unlinkPhotoFromMemory({
    required String memoryId,
    required String photoId,
  }) async {
    await delegate.unlinkPhotoFromMemory(
      memoryId: memoryId,
      photoId: photoId,
    );
    await cloudSyncRepository.enqueueMemory(memoryId);
  }

  @override
  Future<void> setJourneyCoverPhoto({
    required String journeyId,
    String? photoId,
  }) async {
    await delegate.setJourneyCoverPhoto(
      journeyId: journeyId,
      photoId: photoId,
    );
    final photos = await delegate.watchAlbum(journeyId).first;
    for (final photo in photos) {
      await cloudSyncRepository.enqueuePhoto(photo.id);
    }
  }

  @override
  Future<Set<String>> referencedMediaUris() =>
      delegate.referencedMediaUris();

  @override
  Future<void> saveAttachment(MemoryAttachment attachment) =>
      delegate.saveAttachment(attachment);

  @override
  Future<void> deleteAttachment(String attachmentId) =>
      delegate.deleteAttachment(attachmentId);
}
