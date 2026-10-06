import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/features/map_memories/domain/journey_day_resolver.dart';
import 'package:wonderlog/features/map_memories/domain/journey_replay_path_builder.dart';
import 'package:wonderlog/features/map_memories/domain/map_cluster_engine.dart';
import 'package:wonderlog/features/map_memories/domain/map_memory_filter.dart';
import 'package:wonderlog/features/map_memories/domain/map_memory_models.dart';

void main() {
  MapMemoryItem item(
    String id,
    MapMemoryItemType type,
    double lat,
    double lon, {
    int? day,
  }) =>
      MapMemoryItem(
        id: id,
        type: type,
        journeyId: 'j',
        title: id,
        subtitle: 'Campo Tures',
        coordinate: MapCoordinate(latitude: lat, longitude: lon),
        timestamp: DateTime.utc(2026, 8, 10, 10),
        dayIndex: day,
      );

  test('cluster ids remain deterministic for the Flutter wire signature', () {
    const engine = MapClusterEngine(clusterRadiusMeters: 1000);
    final clusters = engine.cluster([
      item('p1', MapMemoryItemType.photo, 46.919, 11.955),
      item('m1', MapMemoryItemType.memory, 46.9191, 11.9551),
    ]);
    expect(clusters, hasLength(1));
    expect(clusters.single.id, '9f733468-0ae1-3ec5-a8a7-866a41d900cf');
  });

  test('filter combines day and content type', () {
    final items = [
      item('p', MapMemoryItemType.photo, 46, 11, day: 0),
      item('m', MapMemoryItemType.memory, 46, 11, day: 1),
    ];
    final result = MapMemoryFilter.apply(
      items,
      const MapMemoryFilterState(
        selectedDayIndex: 1,
        contentFilter: MapMemoryContentFilter.memories,
      ),
    );
    expect(result.map((entry) => entry.id), ['m']);
  });

  test('day resolver is zero based and rejects dates before journey', () {
    expect(
      JourneyDayResolver.resolve(
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 12),
      ),
      2,
    );
    expect(
      JourneyDayResolver.resolve(
        DateTime(2026, 8, 10),
        DateTime(2026, 8, 9),
      ),
      isNull,
    );
  });

  test('replay path skips near duplicate cluster points', () {
    const clusterer = MapClusterEngine(clusterRadiusMeters: 1);
    final clusters = clusterer.cluster([
      item('a', MapMemoryItemType.photo, 46.919, 11.955),
      item('b', MapMemoryItemType.photo, 46.91901, 11.95501),
      item('c', MapMemoryItemType.photo, 46.930, 11.970),
    ]);
    const builder = JourneyReplayPathBuilder(minimumPointDistanceMeters: 50);
    expect(builder.build(clusters).length, greaterThanOrEqualTo(2));
  });
}
