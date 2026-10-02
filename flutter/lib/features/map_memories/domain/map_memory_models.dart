final class MapCoordinate {
  const MapCoordinate({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

enum MapMemoryItemType { photo, memory }

final class MapMemoryItem {
  const MapMemoryItem({
    required this.id,
    required this.type,
    required this.journeyId,
    required this.title,
    required this.subtitle,
    required this.coordinate,
    required this.timestamp,
    this.localPhotoUri,
    this.memoryId,
    this.photoId,
    this.dayIndex,
    this.dateLabel,
  });

  final String id;
  final MapMemoryItemType type;
  final String journeyId;
  final String? title;
  final String? subtitle;
  final MapCoordinate coordinate;
  final DateTime? timestamp;
  final String? localPhotoUri;
  final String? memoryId;
  final String? photoId;
  final int? dayIndex;
  final String? dateLabel;
}

final class MapMemoryCluster {
  const MapMemoryCluster({
    required this.id,
    required this.coordinate,
    required this.items,
    required this.dominantTitle,
    required this.dayIndexes,
  });

  final String id;
  final MapCoordinate coordinate;
  final List<MapMemoryItem> items;
  final String? dominantTitle;
  final Set<int> dayIndexes;

  int get count => items.length;
  int get photoCount =>
      items.where((item) => item.type == MapMemoryItemType.photo).length;
  int get memoryCount =>
      items.where((item) => item.type == MapMemoryItemType.memory).length;

  DateTime? get firstTimestamp {
    final times = items
        .map((item) => item.timestamp)
        .whereType<DateTime>()
        .toList();
    if (times.isEmpty) return null;
    times.sort();
    return times.first;
  }

  DateTime? get lastTimestamp {
    final times = items
        .map((item) => item.timestamp)
        .whereType<DateTime>()
        .toList();
    if (times.isEmpty) return null;
    times.sort();
    return times.last;
  }
}

final class JourneyRoutePoint {
  const JourneyRoutePoint({
    required this.coordinate,
    required this.timestamp,
    required this.clusterId,
    required this.dayIndex,
  });

  final MapCoordinate coordinate;
  final DateTime? timestamp;
  final String? clusterId;
  final int? dayIndex;
}

enum MapMemoryContentFilter { all, photos, memories }

final class MapMemoryFilterState {
  const MapMemoryFilterState({
    this.selectedDayIndex,
    this.contentFilter = MapMemoryContentFilter.all,
  });

  final int? selectedDayIndex;
  final MapMemoryContentFilter contentFilter;
}
