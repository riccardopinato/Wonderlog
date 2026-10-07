import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wonderlog/features/map_memories/domain/map_memory_models.dart';
import 'package:wonderlog/features/map_memories/domain/road_routing_service.dart';

void main() {
  JourneyRoutePoint point(double latitude, double longitude) =>
      JourneyRoutePoint(
        coordinate: MapCoordinate(
          latitude: latitude,
          longitude: longitude,
        ),
        timestamp: null,
        clusterId: null,
        dayIndex: null,
      );

  test('unconfigured routing never calls a public fallback', () async {
    final service = RoadRoutingService(
      baseUrl: '',
      client: MockClient((_) async {
        fail('unconfigured routing must not make a request');
      }),
    );

    expect(
      await service.route([
        point(45.0, 11.0),
        point(45.1, 11.1),
      ]),
      isNull,
    );
  });

  test('configured routing parses OSRM GeoJSON route', () async {
    final client = MockClient((request) async {
      expect(request.url.path, contains('/route/v1/driving/'));
      expect(request.url.queryParameters['geometries'], 'geojson');
      expect(request.url.queryParameters['overview'], 'full');

      return http.Response(
        jsonEncode({
          'routes': [
            {
              'distance': 12345.0,
              'duration': 1450.0,
              'geometry': {
                'type': 'LineString',
                'coordinates': [
                  [11.0, 45.0],
                  [11.05, 45.04],
                  [11.1, 45.1],
                ],
              },
            }
          ],
        }),
        200,
      );
    });
    final service = RoadRoutingService(
      baseUrl: 'https://routing.example.test/',
      client: client,
    );

    final result = await service.route([
      point(45.0, 11.0),
      point(45.1, 11.1),
    ]);

    expect(result, isNotNull);
    expect(result!.points, hasLength(3));
    expect(result.points[1].latitude, 45.04);
    expect(result.distanceMeters, 12345);
    expect(result.durationSeconds, 1450);
  });
}
