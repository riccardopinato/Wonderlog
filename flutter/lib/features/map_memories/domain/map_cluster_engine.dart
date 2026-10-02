import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../smart_journey/domain/geo_math.dart';
import 'map_memory_models.dart';

final class MapClusterEngine {
  const MapClusterEngine({
    this.clusterRadiusMeters = 900,
  });

  final double clusterRadiusMeters;

  List<MapMemoryCluster> cluster(List<MapMemoryItem> items) {
    if (items.isEmpty) return const [];

    final remaining = [...items];
    final clusters = <MapMemoryCluster>[];

    while (remaining.isNotEmpty) {
      final seed = remaining.removeAt(0);
      final members = <MapMemoryItem>[seed];
      var expanded = true;

      while (expanded) {
        expanded = false;
        for (var index = remaining.length - 1; index >= 0; index--) {
          final candidate = remaining[index];
          final close = members.any(
            (member) =>
                GeoMath.distanceMeters(
                  member.coordinate.latitude,
                  member.coordinate.longitude,
                  candidate.coordinate.latitude,
                  candidate.coordinate.longitude,
                ) <=
                clusterRadiusMeters,
          );
          if (close) {
            members.add(candidate);
            remaining.removeAt(index);
            expanded = true;
          }
        }
      }

      final center = GeoMath.centroid(
        members
            .map(
              (item) => (
                latitude: item.coordinate.latitude,
                longitude: item.coordinate.longitude,
              ),
            )
            .toList(growable: false),
      );

      final subtitles = <String, int>{};
      for (final item in members) {
        final value = item.subtitle?.trim();
        if (value != null && value.isNotEmpty) {
          subtitles[value] = (subtitles[value] ?? 0) + 1;
        }
      }

      String? dominant;
      for (final entry in subtitles.entries) {
        if (dominant == null ||
            entry.value > (subtitles[dominant] ?? 0)) {
          dominant = entry.key;
        }
      }
      if (dominant == null) {
        for (final item in members) {
          if (item.title != null) {
            dominant = item.title;
            break;
          }
        }
      }

      final ordered = [...members]
        ..sort((a, b) {
          if (a.timestamp == null && b.timestamp != null) return 1;
          if (a.timestamp != null && b.timestamp == null) return -1;
          if (a.timestamp != null && b.timestamp != null) {
            return a.timestamp!.compareTo(b.timestamp!);
          }
          return a.id.compareTo(b.id);
        });

      clusters.add(
        MapMemoryCluster(
          id: _stableClusterId(members),
          coordinate: MapCoordinate(
            latitude: center?.latitude ?? seed.coordinate.latitude,
            longitude: center?.longitude ?? seed.coordinate.longitude,
          ),
          items: ordered,
          dominantTitle: dominant,
          dayIndexes:
              members.map((item) => item.dayIndex).whereType<int>().toSet(),
        ),
      );
    }

    clusters.sort((a, b) {
      final first = a.firstTimestamp;
      final second = b.firstTimestamp;
      if (first == null && second != null) return 1;
      if (first != null && second == null) return -1;
      if (first == null && second == null) return a.id.compareTo(b.id);
      return first!.compareTo(second!);
    });
    return clusters;
  }

  String _stableClusterId(List<MapMemoryItem> members) {
    final signature = members
        .map((item) => item.type.name + ':' + item.id)
        .toList()
      ..sort();
    return javaNameUuidFromBytes(utf8.encode(signature.join('|')));
  }
}

String javaNameUuidFromBytes(List<int> input) {
  final bytes = Uint8List.fromList(md5.convert(input).bytes);
  bytes[6] = (bytes[6] & 0x0f) | 0x30;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final raw = bytes.map(hex).join();
  return raw.substring(0, 8) +
      '-' +
      raw.substring(8, 12) +
      '-' +
      raw.substring(12, 16) +
      '-' +
      raw.substring(16, 20) +
      '-' +
      raw.substring(20, 32);
}
