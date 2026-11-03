/// Deterministic, offline GPX interchange; no route snapping or filesystem IO.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:xml/xml.dart';

final class GpxFormatException implements Exception {
  const GpxFormatException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => 'GpxFormatException($code): $message';
}

final class GpxPoint {
  GpxPoint(this.latitude, this.longitude,
      {this.elevationMeters, this.timeUtc, this.name}) {
    if (!latitude.isFinite || !longitude.isFinite ||
        latitude < -90 || latitude > 90 ||
        longitude < -180 || longitude > 180 ||
        (elevationMeters != null && !elevationMeters!.isFinite)) {
      throw const GpxFormatException('INVALID_COORDINATE', 'Invalid coordinate/elevation');
    }
  }

  final double latitude, longitude;
  final double? elevationMeters;
  final DateTime? timeUtc;
  final String? name;
}

final class GpxTrack {
  const GpxTrack(this.segments, {this.name});
  final List<List<GpxPoint>> segments;
  final String? name;
}

final class GpxRoute {
  const GpxRoute(this.points, {this.name});
  final List<GpxPoint> points;
  final String? name;
}

final class GpxDocument {
  const GpxDocument({this.name, this.tracks = const [],
      this.routes = const [], this.waypoints = const []});
  final String? name;
  final List<GpxTrack> tracks;
  final List<GpxRoute> routes;
  final List<GpxPoint> waypoints;
  int get pointCount =>
      waypoints.length +
      routes.fold<int>(0, (n, route) => n + route.points.length) +
      tracks.fold<int>(0, (n, track) => n +
          track.segments.fold<int>(0, (m, segment) => m + segment.length));
}

final class GpxParseResult {
  const GpxParseResult(this.document, this.originalPointCount);
  final GpxDocument document;
  final int originalPointCount;
}

final class GpxLimits {
  const GpxLimits({this.maxBytes = 5 * 1024 * 1024,
      this.maxPoints = 10000});
  final int maxBytes, maxPoints;
}

abstract final class GpxReferenceEngine {
  static GpxParseResult parse(String input,
      {GpxLimits limits = const GpxLimits()}) {
    if (limits.maxBytes < 1 || limits.maxPoints < 1) {
      throw ArgumentError('Invalid GPX limits');
    }
    if (utf8.encode(input).length > limits.maxBytes) {
      throw const GpxFormatException('TOO_LARGE', 'GPX file exceeds byte limit');
    }
    if (RegExp(r'<!\s*(DOCTYPE|ENTITY)\b', caseSensitive: false)
        .hasMatch(input)) {
      throw const GpxFormatException('UNSAFE_XML', 'DTD or entity declarations refused');
    }
    late XmlDocument xml;
    try {
      xml = XmlDocument.parse(input);
    } on Exception catch (_) {
      throw const GpxFormatException('MALFORMED_XML', 'Malformed GPX XML');
    }
    final root = xml.rootElement;
    if (root.name.local.toLowerCase() != 'gpx') {
      throw const GpxFormatException('NOT_GPX', 'Expected GPX root');
    }
    var count = 0;
    void bump() {
      count++;
      if (count > limits.maxPoints) {
        throw const GpxFormatException('TOO_MANY_POINTS', 'Exceeded GPX point budget');
      }
    }

    GpxPoint readPoint(XmlElement node) {
      bump();
      final lat = double.tryParse(node.getAttribute('lat') ?? '');
      final lon = double.tryParse(node.getAttribute('lon') ?? '');
      if (lat == null || lon == null) {
        throw const GpxFormatException('INVALID_COORDINATE', 'Missing latitude or longitude');
      }
      final elevText = _childText(node, 'ele');
      final timeText = _childText(node, 'time');
      final elev = elevText == null ? null : double.tryParse(elevText);
      if (elevText != null && elev == null) {
        throw const GpxFormatException('INVALID_ELEVATION', 'Invalid elevation');
      }
      DateTime? time;
      if (timeText != null) {
        try {
          time = DateTime.parse(timeText).toUtc();
        } on FormatException catch (_) {
          throw const GpxFormatException('INVALID_TIME', 'Invalid GPX time');
        }
      }
      return GpxPoint(lat, lon, elevationMeters: elev,
          timeUtc: time, name: _childText(node, 'name'));
    }

    final tracks = <GpxTrack>[];
    for (final trackNode in _children(root, 'trk')) {
      final segments = <List<GpxPoint>>[];
      for (final segment in _children(trackNode, 'trkseg')) {
        final points = _children(segment, 'trkpt').map(readPoint).toList();
        if (points.isNotEmpty) segments.add(List.unmodifiable(points));
      }
      if (segments.isNotEmpty) {
        tracks.add(GpxTrack(List.unmodifiable(segments),
            name: _childText(trackNode, 'name')));
      }
    }
    final routes = <GpxRoute>[];
    for (final route in _children(root, 'rte')) {
      final points = _children(route, 'rtept').map(readPoint).toList();
      if (points.isNotEmpty) {
        routes.add(GpxRoute(List.unmodifiable(points),
            name: _childText(route, 'name')));
      }
    }
    final waypoints = _children(root, 'wpt').map(readPoint).toList();
    if (count == 0) {
      throw const GpxFormatException('EMPTY_GPX', 'No usable GPX points');
    }
    final metadata = _children(root, 'metadata');
    final name = metadata.isEmpty ? null : _childText(metadata.first, 'name');
    return GpxParseResult(GpxDocument(
      name: name,
      tracks: List.unmodifiable(tracks),
      routes: List.unmodifiable(routes),
      waypoints: List.unmodifiable(waypoints),
    ), count);
  }

  static String export(GpxDocument document,
      {GpxLimits limits = const GpxLimits()}) {
    if (document.pointCount < 1) {
      throw const GpxFormatException('EMPTY_GPX', 'No usable GPX points');
    }
    if (document.pointCount > limits.maxPoints) {
      throw const GpxFormatException('TOO_MANY_POINTS', 'Exceeded GPX point budget');
    }
    final out = StringBuffer('<?xml version="1.0" encoding="UTF-8"?>');
    out.write('<gpx version="1.1" creator="App-Factory-Core" '
        'xmlns="http://www.topografix.com/GPX/1/1">');
    if (document.name != null) {
      out.write('<metadata><name>${_escape(document.name!)}</name></metadata>');
    }
    void point(String kind, GpxPoint p) {
      // Revalidate even if malformed objects originated through other adapters.
      GpxPoint(p.latitude, p.longitude, elevationMeters: p.elevationMeters);
      out.write('<$kind lat="${p.latitude.toStringAsFixed(7)}" '
          'lon="${p.longitude.toStringAsFixed(7)}">');
      if (p.elevationMeters != null) {
        out.write('<ele>${p.elevationMeters}</ele>');
      }
      if (p.timeUtc != null) {
        out.write('<time>${p.timeUtc!.toUtc().toIso8601String()}</time>');
      }
      if (p.name != null) out.write('<name>${_escape(p.name!)}</name>');
      out.write('</$kind>');
    }
    for (final p in document.waypoints) {
      point('wpt', p);
    }
    for (final route in document.routes) {
      out.write('<rte>');
      if (route.name != null) out.write('<name>${_escape(route.name!)}</name>');
      for (final p in route.points) { point('rtept', p); }
      out.write('</rte>');
    }
    for (final track in document.tracks) {
      out.write('<trk>');
      if (track.name != null) out.write('<name>${_escape(track.name!)}</name>');
      for (final segment in track.segments) {
        out.write('<trkseg>');
        for (final p in segment) { point('trkpt', p); }
        out.write('</trkseg>');
      }
      out.write('</trk>');
    }
    out.write('</gpx>');
    final encoded = out.toString();
    if (utf8.encode(encoded).length > limits.maxBytes) {
      throw const GpxFormatException('TOO_LARGE', 'Export exceeds byte limit');
    }
    return encoded;
  }

  /// Ramer-Douglas-Peucker per a SINGLE segment; never crosses GPX segments.
  /// Explicit protected indices are always preserved.
  static List<GpxPoint> simplify(List<GpxPoint> input, double toleranceMeters,
      {Set<int> protectedIndices = const {}}) {
    if (!toleranceMeters.isFinite || toleranceMeters < 0 ||
        protectedIndices.any((i) => i < 0 || i >= input.length)) {
      throw ArgumentError('Invalid simplification tolerance/indices');
    }
    if (input.length < 3 || toleranceMeters == 0) return List.unmodifiable(input);
    final keep = <int>{0, input.length - 1, ...protectedIndices};
    final boundaries = keep.toList()..sort();
    for (var s = 0; s < boundaries.length - 1; s++) {
      final pending = <(int, int)>[(boundaries[s], boundaries[s + 1])];
      while (pending.isNotEmpty) {
        final (first, last) = pending.removeLast();
        if (last <= first + 1) continue;
        var maxSquared = -1.0, furthest = -1;
        for (var k = first + 1; k < last; k++) {
          final distance = _segmentDistanceSquared(
              input[k], input[first], input[last]);
          if (distance > maxSquared) {
            maxSquared = distance;
            furthest = k;
          }
        }
        if (maxSquared > toleranceMeters * toleranceMeters && furthest > first) {
          keep.add(furthest);
          pending.add((first, furthest));
          pending.add((furthest, last));
        }
      }
    }
    final sorted = keep.toList()..sort();
    return List.unmodifiable(sorted.map((i) => input[i]));
  }

  static double _segmentDistanceSquared(GpxPoint p, GpxPoint a, GpxPoint b) {
    const metersPerDegree = 111195.0;
    final lat0 = (a.latitude + b.latitude + p.latitude) / 3;
    final cosLat = math.cos(lat0 * math.pi / 180);
    double longitudeDelta(double lon) {
      var delta = lon - a.longitude;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      return delta * cosLat * metersPerDegree;
    }
    final bx = longitudeDelta(b.longitude);
    final by = (b.latitude - a.latitude) * metersPerDegree;
    final px = longitudeDelta(p.longitude);
    final py = (p.latitude - a.latitude) * metersPerDegree;
    final squared = bx * bx + by * by;
    final t = squared == 0 ? 0.0 : ((px * bx + py * by) / squared).clamp(0.0, 1.0);
    final dx = px - t * bx, dy = py - t * by;
    return dx * dx + dy * dy;
  }

  static Iterable<XmlElement> _children(XmlElement parent, String name) =>
      parent.childElements.where((node) => node.name.local == name);

  static String? _childText(XmlElement parent, String name) {
    final match = _children(parent, name);
    if (match.isEmpty) return null;
    final s = match.first.innerText.trim();
    return s.isEmpty ? null : s;
  }

  static String _escape(String value) => value
      .replaceAll('&', '&amp;').replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;').replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
