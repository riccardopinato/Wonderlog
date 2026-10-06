import '../../smart_journey/domain/geo_math.dart';
import 'map_memory_models.dart';

/// Builds a chronological replay trace from geotagged Journey content.
///
/// This is deliberately not a road/trail routing engine: consecutive points
/// are connected in timestamp order and nearby duplicates are collapsed.
final class JourneyReplayPathBuilder {
  const JourneyReplayPathBuilder({
    this.minimumPointDistanceMeters = 50,
  });

  final double minimumPointDistanceMeters;

  List<JourneyRoutePoint> build(List<MapMemoryCluster> clusters) {
    if (clusters.isEmpty) return const [];

    final ordered = [...clusters]
      ..sort((a, b) {
        final first = a.firstTimestamp;
        final second = b.firstTimestamp;
        if (first == null && second != null) return 1;
        if (first != null && second == null) return -1;
        if (first == null && second == null) return a.id.compareTo(b.id);
        return first!.compareTo(second!);
      });

    final result = <JourneyRoutePoint>[];
    for (final cluster in ordered) {
      final last = result.isEmpty ? null : result.last;
      final shouldAdd = last == null ||
          GeoMath.distanceMeters(
                last.coordinate.latitude,
                last.coordinate.longitude,
                cluster.coordinate.latitude,
                cluster.coordinate.longitude,
              ) >=
              minimumPointDistanceMeters;
      if (!shouldAdd) continue;

      final dayIndexes = cluster.dayIndexes.toList()..sort();
      result.add(
        JourneyRoutePoint(
          coordinate: cluster.coordinate,
          timestamp: cluster.firstTimestamp,
          clusterId: cluster.id,
          dayIndex: dayIndexes.isEmpty ? null : dayIndexes.first,
        ),
      );
    }
    return result;
  }
}
