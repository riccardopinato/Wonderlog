import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';
import 'package:wonderlog/features/rediscover/application/rediscover_data_adapter.dart';
import 'package:wonderlog/features/rediscover/domain/journey_replay_builder.dart';
import 'package:wonderlog/features/rediscover/domain/rediscover_engine.dart';
import 'package:wonderlog/features/rediscover/domain/rediscover_models.dart';
import 'package:wonderlog/features/rediscover/domain/rediscover_selection_engine.dart';

void main() {
  test('journey anniversary is generated only for prior years', () {
    const engine = RediscoverEngine();
    final feed = engine.buildFeed(
      today: DateTime(2026, 8, 10),
      journeys: [
        RediscoverJourney(
          id: 'j',
          title: 'Valle Aurina',
          destination: 'Campo Tures',
          startTimestamp: DateTime(2024, 8, 10),
          endTimestamp: DateTime(2024, 8, 14),
          coverPhotoUri: null,
          photoCount: 1,
          memoryCount: 1,
        ),
      ],
      memories: const [],
      photos: const [],
    );
    expect(feed.cards.single.type, RediscoverType.journeyAnniversary);
    expect(feed.cards.single.yearsAgo, 2);
  });

  test('selection caps cards from the same journey at two', () {
    final feed = RediscoverFeed(
      generatedForDayKey: '2026-08-10',
      cards: List.generate(
        4,
        (index) => RediscoverCard(
          id: 'm' + index.toString(),
          type: RediscoverType.memory,
          title: 'Memory',
          subtitle: null,
          journeyId: 'j',
          memoryId: 'm' + index.toString(),
          photoId: null,
          imageUri: 'photo',
          timestamp: DateTime(2025, 8, 10),
        ),
      ),
    );

    expect(RediscoverSelectionEngine.selectForHome(feed), hasLength(2));
  });

  test('replay keeps cover first and end last', () {
    const builder = JourneyReplayBuilder();
    final replay = builder.build(
      journey: RediscoverJourney(
        id: 'j',
        title: 'Trip',
        destination: 'Place',
        startTimestamp: DateTime(2026, 8, 10),
        endTimestamp: DateTime(2026, 8, 14),
        coverPhotoUri: null,
        photoCount: 0,
        memoryCount: 0,
      ),
      photos: const [],
      memories: const [],
    );

    expect(replay.slides.first.type, JourneyReplaySlideType.cover);
    expect(replay.slides.last.type, JourneyReplaySlideType.end);
  });

  test('Rediscover Memory uses only explicitly linked photos', () {
    final now = DateTime.utc(2026, 8, 10);
    final memory = MemoryEntry(
      id: 'memory',
      journeyId: 'journey',
      title: 'Linked Memory',
      journalText: '',
      locationName: '',
      date: now,
      mood: Mood.calm,
      tags: const [],
      createdAt: now,
      updatedAt: now,
    );
    final linked = AlbumPhotoEntry(
      id: 'linked',
      journeyId: 'journey',
      localUri: 'media://linked',
      thumbnailUri: 'media://linked',
      originalUri: '',
      fileName: 'linked.jpg',
      mimeType: 'image/jpeg',
      width: 0,
      height: 0,
      fileSize: 4,
      createdAt: now,
      updatedAt: now,
    );
    final result = RediscoverDataAdapter.memories([
      MemoryWithPhotos(
        memory: memory,
        photos: [linked],
      ),
    ]);

    expect(result.single.photoUris, ['media://linked']);
  });

}
