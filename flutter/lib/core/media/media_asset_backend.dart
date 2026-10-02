import 'media_asset_models.dart';

abstract interface class MediaAssetBackend {
  Future<void> write(String assetId, List<int> bytes);
  Future<List<int>?> read(String assetId);
  Future<bool> delete(String assetId);
  Future<Set<String>> listAssetIds();
  Future<Map<String, MediaAssetStats>> stats();
}

abstract interface class MediaAssetStore {
  Future<String> putOriginal(
    List<int> bytes, {
    String? mimeType,
  });

  Future<String> putNamed(
    String namespace,
    String key,
    List<int> bytes,
  );

  Future<List<int>?> read(String assetId);
  Future<bool> delete(String assetId);
  Future<int> prune(Set<String> referencedAssetIds);
  Future<Set<String>> listStoredAssetIds();
}
