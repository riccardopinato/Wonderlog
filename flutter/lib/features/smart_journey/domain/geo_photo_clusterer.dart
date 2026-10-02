import 'geo_math.dart';
import 'smart_journey_models.dart';

final class SmartJourneyStopCluster {
  const SmartJourneyStopCluster({
    required this.photos,
    required this.latitude,
    required this.longitude,
  });

  final List<SmartJourneySourcePhoto> photos;
  final double? latitude;
  final double? longitude;
}

final class GeoPhotoClusterer {
  const GeoPhotoClusterer(this.options);
  final SmartJourneyBuildOptions options;

  List<SmartJourneyStopCluster> cluster(
    List<SmartJourneySourcePhoto> photos,
  ) {
    if (photos.isEmpty) return const [];

    final sorted = [...photos]..sort(_comparePhotos);
    final clusters = <List<SmartJourneySourcePhoto>>[];

    for (final photo in sorted) {
      if (clusters.isEmpty || !_shouldJoin(clusters.last, photo)) {
        clusters.add(<SmartJourneySourcePhoto>[photo]);
      } else {
        clusters.last.add(photo);
      }
    }

    _mergeOrphanClusters(clusters);

    return clusters.where((cluster) => cluster.isNotEmpty).map((cluster) {
      final coordinates = cluster
          .where(
            (photo) => GeoMath.isValidCoordinate(
              photo.latitude,
              photo.longitude,
            ),
          )
          .map(
            (photo) => (
              latitude: photo.latitude!,
              longitude: photo.longitude!,
            ),
          )
          .toList(growable: false);
      final center = GeoMath.centroid(coordinates);
      return SmartJourneyStopCluster(
        photos: List.unmodifiable(cluster),
        latitude: center?.latitude,
        longitude: center?.longitude,
      );
    }).toList(growable: false);
  }

  bool _shouldJoin(
    List<SmartJourneySourcePhoto> current,
    SmartJourneySourcePhoto candidate,
  ) {
    final previous = current.last;
    if (!_isTimeClose(previous, candidate)) return false;

    final firstGps = GeoMath.isValidCoordinate(
      previous.latitude,
      previous.longitude,
    );
    final secondGps = GeoMath.isValidCoordinate(
      candidate.latitude,
      candidate.longitude,
    );

    if (firstGps && secondGps) {
      return GeoMath.distanceMeters(
            previous.latitude!,
            previous.longitude!,
            candidate.latitude!,
            candidate.longitude!,
          ) <=
          options.geoClusterRadiusMeters;
    }

    return true;
  }

  bool _isTimeClose(
    SmartJourneySourcePhoto first,
    SmartJourneySourcePhoto second,
  ) {
    final a = first.effectiveTimestamp;
    final b = second.effectiveTimestamp;
    if (a == null || b == null) return true;
    return b.difference(a).abs() <=
        Duration(minutes: options.maxStopTimeGapMinutes);
  }

  void _mergeOrphanClusters(List<List<SmartJourneySourcePhoto>> clusters) {
    if (clusters.length <= 1) return;

    var index = 0;
    while (index < clusters.length) {
      final cluster = clusters[index];
      final hasGps = cluster.any(
        (photo) => GeoMath.isValidCoordinate(
          photo.latitude,
          photo.longitude,
        ),
      );
      final tooSmall = cluster.length < options.minimumPhotosPerStop;

      if (!hasGps || tooSmall) {
        final previous = index > 0 ? clusters[index - 1] : null;
        final next = index + 1 < clusters.length ? clusters[index + 1] : null;

        List<SmartJourneySourcePhoto>? destination;
        if (previous != null && next != null) {
          destination = _temporalDistance(cluster, previous) <=
                  _temporalDistance(cluster, next)
              ? previous
              : next;
        } else {
          destination = previous ?? next;
        }

        if (destination != null &&
            _withinOrphanWindow(cluster, destination)) {
          destination.addAll(cluster);
          destination.sort(_comparePhotos);
          clusters.removeAt(index);
          continue;
        }
      }
      index++;
    }
  }

  Duration _temporalDistance(
    List<SmartJourneySourcePhoto> first,
    List<SmartJourneySourcePhoto> second,
  ) {
    DateTime? firstTime;
    DateTime? secondTime;
    for (final photo in first) {
      final time = photo.effectiveTimestamp;
      if (time != null && (firstTime == null || time.isBefore(firstTime))) {
        firstTime = time;
      }
    }
    for (final photo in second) {
      final time = photo.effectiveTimestamp;
      if (time != null && (secondTime == null || time.isBefore(secondTime))) {
        secondTime = time;
      }
    }
    if (firstTime == null || secondTime == null) {
      return const Duration(days: 365000);
    }
    return secondTime.difference(firstTime).abs();
  }

  bool _withinOrphanWindow(
    List<SmartJourneySourcePhoto> first,
    List<SmartJourneySourcePhoto> second,
  ) =>
      _temporalDistance(first, second) <=
      Duration(minutes: options.orphanAssignmentTimeWindowMinutes);

  int _comparePhotos(
    SmartJourneySourcePhoto a,
    SmartJourneySourcePhoto b,
  ) {
    final first = a.effectiveTimestamp;
    final second = b.effectiveTimestamp;
    if (first == null && second != null) return 1;
    if (first != null && second == null) return -1;
    if (first != null && second != null) {
      final result = first.compareTo(second);
      if (result != 0) return result;
    }
    return a.originalIndex.compareTo(b.originalIndex);
  }
}
