import 'dart:math' as math;

abstract final class GeoMath {
  static const double _earthRadiusMeters = 6371000;

  static double distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final latitudeDelta = _radians(lat2 - lat1);
    final longitudeDelta = _radians(lon2 - lon1);
    final firstLatitude = _radians(lat1);
    final secondLatitude = _radians(lat2);

    final a = math.pow(math.sin(latitudeDelta / 2), 2).toDouble() +
        math.cos(firstLatitude) *
            math.cos(secondLatitude) *
            math.pow(math.sin(longitudeDelta / 2), 2).toDouble();

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  static ({double latitude, double longitude})? centroid(
    List<({double latitude, double longitude})> coordinates,
  ) {
    if (coordinates.isEmpty) return null;
    var lat = 0.0;
    var lon = 0.0;
    for (final coordinate in coordinates) {
      lat += coordinate.latitude;
      lon += coordinate.longitude;
    }
    return (
      latitude: lat / coordinates.length,
      longitude: lon / coordinates.length,
    );
  }

  static bool isValidCoordinate(double? latitude, double? longitude) =>
      latitude != null &&
      longitude != null &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  static double _radians(double degrees) => degrees * math.pi / 180;
}
