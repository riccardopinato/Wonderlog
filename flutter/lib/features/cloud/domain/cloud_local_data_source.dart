import 'cloud_models.dart';

final class PhotoCloudDeleteInfo {
  const PhotoCloudDeleteInfo({
    required this.cloudId,
    required this.remoteFilePath,
  });

  final String cloudId;
  final String? remoteFilePath;
}

abstract interface class CloudLocalDataSource {
  Future<CloudJourney?> getJourneyForCloud(String localId);
  Future<CloudMemory?> getMemoryForCloud(String localId);
  Future<CloudAlbumPhoto?> getPhotoForCloud(String localId);

  Future<String?> getPhotoLocalReference(String localId);
  Future<String> buildRemotePhotoPath(String localId);

  Future<void> markJourneyPendingUpload(String localId);
  Future<void> markMemoryPendingUpload(String localId);
  Future<void> markPhotoPendingUpload(String localId);

  Future<void> markJourneySynced(String localId, String cloudId);
  Future<void> markMemorySynced(String localId, String cloudId);
  Future<void> markPhotoSynced(
    String localId,
    String cloudId,
    String? remotePath,
  );

  Future<String?> getJourneyCloudId(String localId);
  Future<String?> getMemoryCloudId(String localId);
  Future<PhotoCloudDeleteInfo?> getPhotoCloudDeleteInfo(String localId);

  Future<void> markJourneyCloudDeleted(String localId);
  Future<void> markMemoryCloudDeleted(String localId);
  Future<void> markPhotoCloudDeleted(String localId);

  Future<List<String>> getPendingJourneyIds();
  Future<List<String>> getPendingMemoryIds();
  Future<List<String>> getPendingPhotoIds();
}
