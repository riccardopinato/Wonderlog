final class LocationPlace {
  const LocationPlace({
    required this.id,
    required this.displayName,
    required this.country,
    required this.city,
    required this.region,
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  final String id;
  final String displayName;
  final String country;
  final String city;
  final String region;
  final double latitude;
  final double longitude;
  final String source;
}

final class OfflineMapRegion {
  const OfflineMapRegion({
    required this.id,
    required this.name,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusKm,
    required this.zoomMin,
    required this.zoomMax,
    this.sizeBytes = 0,
    this.isDownloaded = false,
    this.downloadProgress = 0,
    required this.createdAt,
  });

  final String id;
  final String name;
  final double centerLatitude;
  final double centerLongitude;
  final double radiusKm;
  final int zoomMin;
  final int zoomMax;
  final int sizeBytes;
  final bool isDownloaded;
  final double downloadProgress;
  final DateTime createdAt;

  OfflineMapRegion copyWith({
    String? name,
    double? centerLatitude,
    double? centerLongitude,
    double? radiusKm,
    int? zoomMin,
    int? zoomMax,
    int? sizeBytes,
    bool? isDownloaded,
    double? downloadProgress,
  }) =>
      OfflineMapRegion(
        id: id,
        name: name ?? this.name,
        centerLatitude: centerLatitude ?? this.centerLatitude,
        centerLongitude: centerLongitude ?? this.centerLongitude,
        radiusKm: radiusKm ?? this.radiusKm,
        zoomMin: zoomMin ?? this.zoomMin,
        zoomMax: zoomMax ?? this.zoomMax,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        isDownloaded: isDownloaded ?? this.isDownloaded,
        downloadProgress: downloadProgress ?? this.downloadProgress,
        createdAt: createdAt,
      );
}

enum TileCachePolicy {
  cacheFirst,
  networkFirst,
  offlineOnly,
}
