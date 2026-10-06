import 'location_models.dart';

enum OfflineMapAvailability {
  available,
  unsupportedPlatform,
  providerNotConfigured,
}

final class OfflineMapDownloadProgress {
  const OfflineMapDownloadProgress({
    required this.fraction,
    required this.downloadedBytes,
    required this.completedResources,
    required this.requiredResources,
  });

  final double fraction;
  final int downloadedBytes;
  final int completedResources;
  final int requiredResources;
}

abstract interface class OfflineMapService {
  OfflineMapAvailability get availability;

  Future<OfflineMapRegion> download(
    OfflineMapRegion region, {
    required void Function(OfflineMapDownloadProgress progress) onProgress,
  });

  Future<void> delete(OfflineMapRegion region);

  Future<bool> isDownloaded(String wonderlogRegionId);
}
