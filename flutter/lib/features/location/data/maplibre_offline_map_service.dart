import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as ml;

import '../domain/location_models.dart';
import '../domain/offline_map_service.dart';

final class MapLibreOfflineMapService implements OfflineMapService {
  MapLibreOfflineMapService({
    required String styleUrl,
  }) : styleUrl = styleUrl.trim();

  final String styleUrl;

  @override
  OfflineMapAvailability get availability {
    if (kIsWeb) return OfflineMapAvailability.unsupportedPlatform;
    final nativeMobile = defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (!nativeMobile) return OfflineMapAvailability.unsupportedPlatform;
    if (styleUrl.isEmpty) {
      return OfflineMapAvailability.providerNotConfigured;
    }
    return OfflineMapAvailability.available;
  }

  @override
  Future<OfflineMapRegion> download(
    OfflineMapRegion region, {
    required void Function(OfflineMapDownloadProgress progress) onProgress,
  }) async {
    if (availability != OfflineMapAvailability.available) {
      throw StateError('Offline map download is not available.');
    }

    final bounds = _boundsFor(region);
    var downloadedBytes = 0;

    final downloaded = await ml.downloadOfflineRegion(
      ml.OfflineRegionDefinition(
        bounds: bounds,
        mapStyleUrl: styleUrl,
        minZoom: region.zoomMin.toDouble(),
        maxZoom: region.zoomMax.toDouble(),
      ),
      metadata: {
        'wonderlogRegionId': region.id,
        'name': region.name,
      },
      onEvent: (event) {
        if (event is! ml.InProgress) return;
        downloadedBytes = event.completedResourceSize;
        onProgress(
          OfflineMapDownloadProgress(
            fraction: event.progress.clamp(0.0, 1.0),
            downloadedBytes: event.completedResourceSize,
            completedResources: event.completedResourceCount,
            requiredResources: event.requiredResourceCount,
          ),
        );
      },
    );

    final status = await ml.getOfflineRegionStatus(downloaded.id);
    downloadedBytes = math.max(
      downloadedBytes,
      status.completedResourceSize,
    );

    return region.copyWith(
      sizeBytes: downloadedBytes,
      isDownloaded: status.complete,
      downloadProgress: status.complete ? 1 : status.progress.clamp(0.0, 1.0),
    );
  }

  @override
  Future<void> delete(OfflineMapRegion region) async {
    if (kIsWeb) return;
    final nativeRegions = await ml.getListOfRegions();
    for (final native in nativeRegions) {
      if (native.metadata['wonderlogRegionId']?.toString() != region.id) {
        continue;
      }
      await ml.deleteOfflineRegion(native.id);
    }
    await ml.clearAmbientCache();
  }

  @override
  Future<bool> isDownloaded(String wonderlogRegionId) async {
    if (availability != OfflineMapAvailability.available) return false;
    final regions = await ml.getListOfRegions();
    for (final region in regions) {
      if (region.metadata['wonderlogRegionId']?.toString() !=
          wonderlogRegionId) {
        continue;
      }
      final status = await ml.getOfflineRegionStatus(region.id);
      return status.complete;
    }
    return false;
  }

  ml.LatLngBounds _boundsFor(OfflineMapRegion region) {
    final radiusKm = region.radiusKm.clamp(0.25, 100.0);
    final latitudeDelta = radiusKm / 110.574;
    final latitudeRadians = region.centerLatitude * math.pi / 180;
    final longitudeScale = math.cos(latitudeRadians).abs().clamp(0.05, 1.0);
    final longitudeDelta = radiusKm / (111.320 * longitudeScale);

    final south = (region.centerLatitude - latitudeDelta).clamp(-85.0, 85.0);
    final north = (region.centerLatitude + latitudeDelta).clamp(-85.0, 85.0);
    final west = _wrapLongitude(region.centerLongitude - longitudeDelta);
    final east = _wrapLongitude(region.centerLongitude + longitudeDelta);

    return ml.LatLngBounds(
      southwest: ml.LatLng(south, west),
      northeast: ml.LatLng(north, east),
    );
  }

  double _wrapLongitude(double value) {
    var result = value;
    while (result < -180) {
      result += 360;
    }
    while (result >= 180) {
      result -= 360;
    }
    return result;
  }
}
