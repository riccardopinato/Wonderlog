import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/journeys/domain/journey.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';
import 'package:wonderlog/features/timeline/domain/timeline_engine.dart';
import 'package:wonderlog/features/timeline/domain/timeline_models.dart';

void main() {
  final journey = Journey(
    id: 'j',
    title: 'Trip',
    destination: 'Place',
    country: '',
    startDate: DateTime(2026, 8, 10),
    endDate: DateTime(2026, 8, 14),
    description: '',
    latitude: 0,
    longitude: 0,
    favorite: false,
    archived: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  MemoryWithPhotos item(String id, DateTime date, {bool favorite = false}) =>
      MemoryWithPhotos(
        memory: MemoryEntry(
          id: id,
          journeyId: 'j',
          title: id,
          journalText: 'journal',
          locationName: 'Campo Tures',
          date: date,
          mood: Mood.happy,
          tags: const ['trip'],
          favorite: favorite,
          createdAt: date,
          updatedAt: date,
        ),
        photos: const [],
      );

  test('timeline groups memories by day and computes travel day', () {
    final result = const TimelineEngine().generateTimeline(
      journey: journey,
      memories: [
        item('a', DateTime(2026, 8, 10)),
        item('b', DateTime(2026, 8, 11)),
      ],
      sort: TimelineSort.oldestFirst,
      filter: const TimelineFilter(),
    );
    expect(result, hasLength(2));
    expect(result.first.title, startsWith('Day 1'));
    expect(result.last.title, startsWith('Day 2'));
  });

  test('favorite filter matches Kotlin donor behavior', () {
    final result = const TimelineEngine().generateTimeline(
      journey: journey,
      memories: [
        item('a', DateTime(2026, 8, 10)),
        item('b', DateTime(2026, 8, 11), favorite: true),
      ],
      sort: TimelineSort.oldestFirst,
      filter: const TimelineFilter(showOnlyFavorites: true),
    );
    expect(result.single.memories.single.memoryId, 'b');
  });
}
