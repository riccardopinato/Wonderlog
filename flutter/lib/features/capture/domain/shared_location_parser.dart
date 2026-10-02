import 'capture_models.dart';

abstract final class SharedLocationParser {
  static final RegExp _geo = RegExp(
    r'geo:(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
  );
  static final RegExp _at = RegExp(
    r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
  );
  static final RegExp _query = RegExp(
    r'[?&]q=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
  );

  static CaptureLocation? parse(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    for (final pattern in [_geo, _at, _query]) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final latitude = double.tryParse(match.group(1) ?? '');
      final longitude = double.tryParse(match.group(2) ?? '');
      if (latitude != null &&
          longitude != null &&
          latitude >= -90 &&
          latitude <= 90 &&
          longitude >= -180 &&
          longitude <= 180) {
        return CaptureLocation(
          latitude: latitude,
          longitude: longitude,
        );
      }
    }
    return null;
  }
}
