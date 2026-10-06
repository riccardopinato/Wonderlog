import '../../journeys/domain/journey.dart';
import '../../memories/domain/memory_models.dart';
import '../domain/rediscover_models.dart';

abstract final class RediscoverDataAdapter {
  static List<RediscoverJourney> journeys(
    List<Journey> journeys,
    List<AlbumPhotoEntry> photos,
    List<MemoryEntry> memories,
  ) =>
      journeys.map((journey) {
        final journeyPhotos =
            photos.where((photo) => photo.journeyId == journey.id).toList();
        final journeyMemories =
            memories.where((memory) => memory.journeyId == journey.id).toList();
        String? cover;
        for (final photo in journeyPhotos) {
          if (photo.isCoverPhoto) {
            cover = photo.localUri;
            break;
          }
        }
        if (cover == null && journeyPhotos.isNotEmpty) {
          cover = journeyPhotos.first.localUri;
        }

        return RediscoverJourney(
          id: journey.id,
          title: journey.title,
          destination: journey.destination,
          startTimestamp: journey.startDate,
          endTimestamp: journey.endDate,
          coverPhotoUri: cover,
          photoCount: journeyPhotos.length,
          memoryCount: journeyMemories.length,
        );
      }).toList(growable: false);

  static List<RediscoverMemory> memories(
    List<MemoryWithPhotos> items,
  ) =>
      items.map((item) {
        final memory = item.memory;
        return RediscoverMemory(
          id: memory.id,
          journeyId: memory.journeyId,
          title: memory.title,
          journalText: memory.journalText,
          timestamp: memory.date,
          locationName: memory.locationName,
          photoUris: item.photos
              .map((photo) => photo.localUri)
              .toList(growable: false),
        );
      }).toList(growable: false);

  static List<RediscoverPhoto> photos(List<AlbumPhotoEntry> photos) =>
      photos.map((photo) {
        return RediscoverPhoto(
          id: photo.id,
          journeyId: photo.journeyId,
          localUri: photo.localUri,
          timestamp: photo.capturedAt ?? photo.createdAt,
          locationName: photo.locationName,
        );
      }).toList(growable: false);
}
