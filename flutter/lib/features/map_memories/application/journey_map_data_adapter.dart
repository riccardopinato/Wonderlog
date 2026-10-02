import '../../journeys/domain/journey.dart';
import '../../memories/domain/memory_models.dart';
import '../domain/journey_day_resolver.dart';
import '../domain/map_memory_models.dart';

abstract final class JourneyMapDataAdapter {
  static List<MapMemoryItem> build({
    required Journey journey,
    required List<MemoryEntry> memories,
    required List<AlbumPhotoEntry> photos,
  }) {
    final items = <MapMemoryItem>[];

    for (final memory in memories) {
      final coordinate = memory.coordinate;
      if (coordinate == null) continue;
      items.add(
        MapMemoryItem(
          id: memory.id,
          type: MapMemoryItemType.memory,
          journeyId: memory.journeyId,
          title: memory.title,
          subtitle: memory.locationName,
          coordinate: MapCoordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
          ),
          timestamp: memory.date,
          memoryId: memory.id,
          dayIndex: JourneyDayResolver.resolve(
            journey.startDate,
            memory.date,
          ),
          dateLabel: memory.date.toIso8601String(),
        ),
      );
    }

    for (final photo in photos) {
      final coordinate = photo.gpsCoordinate;
      if (coordinate == null) continue;
      final timestamp = photo.capturedAt ?? photo.createdAt;
      items.add(
        MapMemoryItem(
          id: photo.id,
          type: MapMemoryItemType.photo,
          journeyId: photo.journeyId,
          title: photo.fileName,
          subtitle: photo.locationName,
          coordinate: MapCoordinate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
          ),
          timestamp: timestamp,
          localPhotoUri: photo.localUri,
          photoId: photo.id,
          dayIndex: JourneyDayResolver.resolve(
            journey.startDate,
            timestamp,
          ),
          dateLabel: timestamp.toIso8601String(),
        ),
      );
    }

    items.sort((a, b) {
      final first = a.timestamp;
      final second = b.timestamp;
      if (first == null && second != null) return 1;
      if (first != null && second == null) return -1;
      if (first != null && second != null) {
        final byTime = first.compareTo(second);
        if (byTime != 0) return byTime;
      }
      return a.id.compareTo(b.id);
    });
    return items;
  }
}
