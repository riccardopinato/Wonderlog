import '../../memories/domain/memory_models.dart';

final class TimelineItem {
  const TimelineItem({
    required this.memoryId,
    required this.title,
    required this.journalPreview,
    required this.date,
    required this.locationName,
    required this.mood,
    required this.heroPhoto,
    required this.photoCount,
    required this.favorite,
    required this.displayOrder,
  });

  final String memoryId;
  final String title;
  final String journalPreview;
  final DateTime date;
  final String locationName;
  final Mood mood;
  final String heroPhoto;
  final int photoCount;
  final bool favorite;
  final int displayOrder;
}

final class TimelineDay {
  const TimelineDay({
    required this.date,
    required this.title,
    required this.subtitle,
    required this.memories,
    required this.photoCount,
    required this.moods,
    required this.locations,
  });

  final DateTime date;
  final String title;
  final String subtitle;
  final List<TimelineItem> memories;
  final int photoCount;
  final List<Mood> moods;
  final List<String> locations;
}

enum TimelineSort {
  oldestFirst,
  newestFirst,
  favoritesFirst,
  byMood,
  byLocation,
}

final class TimelineFilter {
  const TimelineFilter({
    this.showOnlyFavorites = false,
    this.selectedMood,
    this.selectedTag,
    this.selectedLocation,
    this.dateRangeStart,
    this.dateRangeEnd,
    this.hasPhotosOnly = false,
    this.noPhotosOnly = false,
  });

  final bool showOnlyFavorites;
  final Mood? selectedMood;
  final String? selectedTag;
  final String? selectedLocation;
  final DateTime? dateRangeStart;
  final DateTime? dateRangeEnd;
  final bool hasPhotosOnly;
  final bool noPhotosOnly;

  TimelineFilter copyWith({
    bool? showOnlyFavorites,
    Mood? selectedMood,
    bool clearMood = false,
    String? selectedTag,
    bool clearTag = false,
    String? selectedLocation,
    bool clearLocation = false,
    DateTime? dateRangeStart,
    DateTime? dateRangeEnd,
    bool? hasPhotosOnly,
    bool? noPhotosOnly,
  }) =>
      TimelineFilter(
        showOnlyFavorites:
            showOnlyFavorites ?? this.showOnlyFavorites,
        selectedMood: clearMood ? null : selectedMood ?? this.selectedMood,
        selectedTag: clearTag ? null : selectedTag ?? this.selectedTag,
        selectedLocation:
            clearLocation ? null : selectedLocation ?? this.selectedLocation,
        dateRangeStart: dateRangeStart ?? this.dateRangeStart,
        dateRangeEnd: dateRangeEnd ?? this.dateRangeEnd,
        hasPhotosOnly: hasPhotosOnly ?? this.hasPhotosOnly,
        noPhotosOnly: noPhotosOnly ?? this.noPhotosOnly,
      );
}
