import 'dart:typed_data';

import 'cloud_models.dart';

abstract interface class CloudProvider {
  Future<bool> isAuthenticated();

  Future<CloudJourney> uploadJourney(CloudJourney payload);
  Future<CloudMemory> uploadMemory(CloudMemory payload);
  Future<CloudAlbumPhoto> uploadPhotoMetadata(CloudAlbumPhoto payload);

  Future<String> uploadPhotoFile(
    Uint8List bytes,
    String remotePath,
  );

  Future<void> deleteJourney(String cloudId);
  Future<void> deleteMemory(String cloudId);
  Future<void> deletePhoto(
    String cloudId,
    String? remoteFilePath,
  );

  Future<List<CloudJourney>> fetchJourneys(DateTime? updatedAfter);
  Future<List<CloudMemory>> fetchMemories(DateTime? updatedAfter);
  Future<List<CloudAlbumPhoto>> fetchPhotos(DateTime? updatedAfter);

  Future<Uint8List> downloadPhotoFile(String remotePath);

  Future<void> uploadMemoryPhotoLinks(
    List<CloudMemoryPhotoLink> links,
  );

  Future<List<CloudMemoryPhotoLink>> fetchMemoryPhotoLinks();
}
