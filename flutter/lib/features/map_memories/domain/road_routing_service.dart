import 'dart:convert';

import 'package:http/http.dart' as http;

import 'map_memory_models.dart';

final class RoadRouteResult {
  const RoadRouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final List<MapCoordinate> points;
  final double distanceMeters;
  final double durationSeconds;
}

/// OSRM-compatible routing adapter.
///
/// No public/demo routing endpoint is hardcoded. Production routing is enabled
/// only when WONDERLOG_ROUTING_URL points to a provider the app is allowed to
/// use, or to infrastructure controlled by Wonderlog.
final class RoadRoutingService {
  RoadRoutingService({
    required String baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''),
        client = client ?? http.Client();

  final String baseUrl;
  final http.Client client;

  bool get configured => baseUrl.isNotEmpty;

  Future<RoadRouteResult?> route(
    List<JourneyRoutePoint> waypoints,
  ) async {
    if (!configured || waypoints.length < 2) return null;

    final coordinates = waypoints
        .map(
          (point) =>
              '${point.coordinate.longitude},${point.coordinate.latitude}',
        )
        .join(';');

    final uri = Uri.parse(
      '$baseUrl/route/v1/driving/$coordinates',
    ).replace(
      queryParameters: const {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'false',
      },
    );

    final response = await client
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return null;
    final map = Map<String, Object?>.from(decoded);
    final routesRaw = map['routes'];
    if (routesRaw is! List || routesRaw.isEmpty) return null;
    final first = routesRaw.first;
    if (first is! Map) return null;
    final route = Map<String, Object?>.from(first);
    final geometryRaw = route['geometry'];
    if (geometryRaw is! Map) return null;
    final geometry = Map<String, Object?>.from(geometryRaw);
    final coordinatesRaw = geometry['coordinates'];
    if (coordinatesRaw is! List) return null;

    final points = <MapCoordinate>[];
    for (final raw in coordinatesRaw) {
      if (raw is! List || raw.length < 2) continue;
      final longitude = (raw[0] as num?)?.toDouble();
      final latitude = (raw[1] as num?)?.toDouble();
      if (latitude == null || longitude == null) continue;
      points.add(
        MapCoordinate(
          latitude: latitude,
          longitude: longitude,
        ),
      );
    }
    if (points.length < 2) return null;

    return RoadRouteResult(
      points: points,
      distanceMeters: (route['distance'] as num?)?.toDouble() ?? 0,
      durationSeconds: (route['duration'] as num?)?.toDouble() ?? 0,
    );
  }
}
