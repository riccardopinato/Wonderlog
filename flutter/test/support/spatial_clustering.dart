/// Deterministic distance-based spatial connected components for local points.
/// This is a pure reference, not map matching, geocoding or GPS accuracy proof.
library;
import 'dart:math' as math;

final class SpatialReferenceException implements Exception {
  const SpatialReferenceException(this.code);
  final String code;
}

final class SpatialPoint {
  SpatialPoint(this.id, this.latitude, this.longitude) {
    if (id.trim().isEmpty || id.length > 200 ||
        !latitude.isFinite || latitude < -90 || latitude > 90 ||
        !longitude.isFinite || longitude < -180 || longitude > 180) {
      throw const SpatialReferenceException('INVALID_POINT');
    }
  }
  final String id;
  final double latitude, longitude;
}

final class SpatialCluster {
  const SpatialCluster(this.id, this.points);
  /// Stable cluster key: the lexicographically first member ID.
  final String id;
  final List<SpatialPoint> points;
}

abstract final class SpatialReferenceClustering {
  static const double earthRadiusMeters = 6371008.8;

  static double distanceMeters(SpatialPoint a, SpatialPoint b) {
    // Equivalent antimeridian and pole coordinates must have exact zero distance.
    if (a.latitude == b.latitude &&
        (a.longitude == b.longitude ||
         (a.longitude.abs() == 180 && b.longitude.abs() == 180) ||
         a.latitude.abs() == 90)) return 0;
    const radians = math.pi / 180;
    final phiA = a.latitude * radians;
    final phiB = b.latitude * radians;
    final dPhi = (b.latitude - a.latitude) * radians;
    // sin² is periodic, so ±180° crossing is handled without a special case.
    final dLambda = (b.longitude - a.longitude) * radians;
    final h = math.pow(math.sin(dPhi / 2), 2) +
        math.cos(phiA) * math.cos(phiB) *
        math.pow(math.sin(dLambda / 2), 2);
    return 2 * earthRadiusMeters * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
  }

  /// Single-linkage connectivity: a chain can span farther than radius.
  /// Complexity O(n²); cap prevents accidental unbounded mobile workloads.
  static List<SpatialCluster> cluster(
    Iterable<SpatialPoint> input, {
    required double radiusMeters,
    int maxPoints = 2000,
  }) {
    if (!radiusMeters.isFinite || radiusMeters < 0 ||
        maxPoints < 1 || maxPoints > 10000) {
      throw const SpatialReferenceException('INVALID_CONFIGURATION');
    }
    final points = <SpatialPoint>[];
    for (final point in input) {
      if (points.length == maxPoints) {
        throw const SpatialReferenceException('TOO_MANY_POINTS');
      }
      points.add(point);
    }
    points.sort((a, b) => a.id.compareTo(b.id));
    for (var i = 1; i < points.length; i++) {
      if (points[i].id == points[i - 1].id) {
        throw const SpatialReferenceException('DUPLICATE_ID');
      }
    }
    final parent = List<int>.generate(points.length, (i) => i);
    int root(int i) {
      while (parent[i] != i) {
        parent[i] = parent[parent[i]];
        i = parent[i];
      }
      return i;
    }
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        if (distanceMeters(points[i], points[j]) <= radiusMeters) {
          final a = root(i), b = root(j);
          if (a != b) parent[b] = a;
        }
      }
    }
    final groups = <int, List<SpatialPoint>>{};
    for (var i = 0; i < points.length; i++) {
      groups.putIfAbsent(root(i), () => []).add(points[i]);
    }
    final result = groups.values.map((members) =>
      SpatialCluster(members.first.id, List<SpatialPoint>.unmodifiable(members)))
        .toList()..sort((a, b) => a.id.compareTo(b.id));
    return List<SpatialCluster>.unmodifiable(result);
  }

  /// Deterministic zoom-dependent grid buckets, distinct from meter-radius
  /// single-linkage clustering. Longitude wraps at the antimeridian.
  /// A seam-adjacent pair of occupied buckets in the same latitude row is
  /// merged if both contain points near the seam; no GPS/map provider needed.
  /// Complexity O(n log n), max 10k inputs by default.
  static List<SpatialCluster> clusterGrid(
    Iterable<SpatialPoint> input, {
    required double zoom,
    int maxPoints = 10000,
  }) {
    if (!zoom.isFinite || zoom < 0 || zoom > 24 ||
        maxPoints < 1 || maxPoints > 10000) {
      throw const SpatialReferenceException('INVALID_CONFIGURATION');
    }
    final pts = <SpatialPoint>[];
    for (final p in input) {
      if (pts.length >= maxPoints) {
        throw const SpatialReferenceException('TOO_MANY_POINTS');
      }
      pts.add(p);
    }
    pts.sort((a, b) => a.id.compareTo(b.id));
    for (var i = 1; i < pts.length; i++) {
      if (pts[i].id == pts[i - 1].id) {
        throw const SpatialReferenceException('DUPLICATE_ID');
      }
    }
    if (pts.isEmpty) return const [];
    final normalized = (zoom - 8).clamp(0.0, 8.0);
    final cell = (0.42 / math.pow(2, normalized))
        .clamp(0.0025, 0.42).toDouble();
    final columns = (360.0 / cell).ceil();
    final buckets = <String, List<SpatialPoint>>{};
    final rows = <int>{};
    for (final p in pts) {
      // 180 and -180 have the same topological longitude.
      final col = (((p.longitude + 180.0) / cell).floor()) % columns;
      final row = ((p.latitude + 90.0) / cell).floor();
      rows.add(row);
      buckets.putIfAbsent('$row:$col', () => []).add(p);
    }
    for (final row in rows) {
      final left = buckets['$row:0'];
      final right = buckets['$row:${columns - 1}'];
      if (left == null || right == null || identical(left, right)) continue;
      final leftNear = left.any((p) => (p.longitude + 180).abs() <= cell);
      final rightNear = right.any((p) => (p.longitude - 180).abs() <= cell);
      if (leftNear && rightNear) {
        left.addAll(right);
        buckets.remove('$row:${columns - 1}');
      }
    }
    final output = <SpatialCluster>[];
    for (final group in buckets.values) {
      group.sort((a, b) => a.id.compareTo(b.id));
      output.add(SpatialCluster(group.first.id, List.unmodifiable(group)));
    }
    output.sort((a, b) => a.id.compareTo(b.id));
    return List.unmodifiable(output);
  }
}
