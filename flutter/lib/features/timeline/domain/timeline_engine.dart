import 'package:intl/intl.dart';

import '../../journeys/domain/journey.dart';
import '../../memories/domain/memory_models.dart';
import 'timeline_models.dart';

final class TimelineEngine {
  const TimelineEngine();

  List<TimelineDay> generateTimeline({
    required Journey journey,
    required List<MemoryWithPhotos> memories,
    required TimelineSort sort,
    required TimelineFilter filter,
    String locale = 'en',
  }) {
    final filtered = _filterMemories(memories, filter);
    final grouped = <String, List<MemoryWithPhotos>>{};

    for (final item in filtered) {
      final key = _dateKey(item.memory.date);
      grouped.putIfAbsent(key, () => <MemoryWithPhotos>[]).add(item);
    }

    final days = <TimelineDay>[];
    for (final entry in grouped.entries) {
      final date = DateTime.parse(entry.key);
      final sorted = _sortMemories(entry.value, sort)
          .map(_toTimelineItem)
          .toList(growable: false);
      final totalPhotos =
          sorted.fold<int>(0, (sum, item) => sum + item.photoCount);
      final moods = sorted.map((item) => item.mood).toSet().toList();
      final locations = sorted
          .map((item) => item.locationName.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

      final dayNumber = _dayNumber(date, journey.startDate);
      final firstTitle = sorted.isEmpty ? '' : sorted.first.title;
      final title = firstTitle.isNotEmpty
          ? 'Day ' + dayNumber.toString() + ' · ' + firstTitle
          : 'Day ' +
              dayNumber.toString() +
              ' · ' +
              DateFormat.yMMMd(locale).format(date);

      final memoryLabel = sorted.length == 1
          ? '1 memory'
          : sorted.length.toString() + ' memories';
      final photoLabel = totalPhotos == 1
          ? '1 photo'
          : totalPhotos.toString() + ' photos';
      final locationSummary = locations.isEmpty
          ? 'No locations'
          : '📍 ' + locations.take(2).join(', ');

      days.add(
        TimelineDay(
          date: date,
          title: title,
          subtitle:
              memoryLabel + ' · ' + photoLabel + ' · ' + locationSummary,
          memories: sorted,
          photoCount: totalPhotos,
          moods: moods,
          locations: locations,
        ),
      );
    }

    return switch (sort) {
      TimelineSort.oldestFirst => days
        ..sort((a, b) => a.date.compareTo(b.date)),
      TimelineSort.newestFirst => days
        ..sort((a, b) => b.date.compareTo(a.date)),
      TimelineSort.favoritesFirst => days
        ..sort(
          (a, b) => _hasFavorite(b).toString().compareTo(
                _hasFavorite(a).toString(),
              ),
        ),
      TimelineSort.byMood => days
        ..sort(
          (a, b) => _firstMood(a).compareTo(_firstMood(b)),
        ),
      TimelineSort.byLocation => days
        ..sort(
          (a, b) => _firstLocation(a).compareTo(_firstLocation(b)),
        ),
    };
  }

  List<MemoryWithPhotos> _filterMemories(
    List<MemoryWithPhotos> memories,
    TimelineFilter filter,
  ) =>
      memories.where((item) {
        final memory = item.memory;
        if (filter.showOnlyFavorites && !memory.favorite) return false;
        if (filter.selectedMood != null &&
            memory.mood != filter.selectedMood) {
          return false;
        }
        if (filter.selectedTag != null &&
            !memory.tags.contains(filter.selectedTag)) {
          return false;
        }
        if (filter.selectedLocation != null &&
            !memory.locationName.toLowerCase().contains(
                  filter.selectedLocation!.toLowerCase(),
                )) {
          return false;
        }
        if (filter.dateRangeStart != null &&
            memory.date.isBefore(filter.dateRangeStart!)) {
          return false;
        }
        if (filter.dateRangeEnd != null &&
            memory.date.isAfter(filter.dateRangeEnd!)) {
          return false;
        }

        final hasPhotos = item.photos.isNotEmpty;
        if (filter.hasPhotosOnly && !hasPhotos) return false;
        if (filter.noPhotosOnly && hasPhotos) return false;
        return true;
      }).toList(growable: false);

  List<MemoryWithPhotos> _sortMemories(
    List<MemoryWithPhotos> memories,
    TimelineSort sort,
  ) {
    final result = [...memories];
    switch (sort) {
      case TimelineSort.oldestFirst:
        result.sort(_oldest);
      case TimelineSort.newestFirst:
        result.sort((a, b) => _oldest(b, a));
      case TimelineSort.favoritesFirst:
        result.sort((a, b) {
          final favorite =
              (b.memory.favorite ? 1 : 0) - (a.memory.favorite ? 1 : 0);
          if (favorite != 0) return favorite;
          return b.memory.date.compareTo(a.memory.date);
        });
      case TimelineSort.byMood:
        result.sort(
          (a, b) => a.memory.mood.label.compareTo(b.memory.mood.label),
        );
      case TimelineSort.byLocation:
        result.sort(
          (a, b) => a.memory.locationName.compareTo(b.memory.locationName),
        );
    }
    return result;
  }

  int _oldest(MemoryWithPhotos a, MemoryWithPhotos b) {
    final date = a.memory.date.compareTo(b.memory.date);
    if (date != 0) return date;
    final display = a.memory.displayOrder.compareTo(b.memory.displayOrder);
    if (display != 0) return display;
    return a.memory.createdAt.compareTo(b.memory.createdAt);
  }

  TimelineItem _toTimelineItem(MemoryWithPhotos item) {
    final memory = item.memory;
    final journal = memory.journalText;
    final preview = journal.length > 120
        ? journal.substring(0, 117) + '...'
        : journal;

    return TimelineItem(
      memoryId: memory.id,
      title: memory.title,
      journalPreview: preview,
      date: memory.date,
      locationName: memory.locationName,
      mood: memory.mood,
      heroPhoto: item.photos.isEmpty ? '' : item.photos.first.localUri,
      photoCount: item.photos.length,
      favorite: memory.favorite,
      displayOrder: memory.displayOrder,
    );
  }

  int _dayNumber(DateTime memoryDate, DateTime startDate) {
    final start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    final current = DateTime(
      memoryDate.year,
      memoryDate.month,
      memoryDate.day,
    );
    final days = current.difference(start).inDays;
    return days >= 0 ? days + 1 : 1;
  }

  String _dateKey(DateTime date) =>
      date.year.toString().padLeft(4, '0') +
      '-' +
      date.month.toString().padLeft(2, '0') +
      '-' +
      date.day.toString().padLeft(2, '0');

  bool _hasFavorite(TimelineDay day) =>
      day.memories.any((item) => item.favorite);

  String _firstMood(TimelineDay day) =>
      day.memories.isEmpty ? '' : day.memories.first.mood.label;

  String _firstLocation(TimelineDay day) =>
      day.memories.isEmpty ? '' : day.memories.first.locationName;
}
