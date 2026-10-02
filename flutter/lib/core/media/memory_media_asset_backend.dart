import 'media_asset_backend.dart';
import 'media_asset_models.dart';

final class MemoryMediaAssetBackend implements MediaAssetBackend {
  final Map<String, List<int>> _data = {};
  final Map<String, DateTime> _lastAccess = {};

  @override
  Future<void> write(String assetId, List<int> bytes) async {
    _data[assetId] = List<int>.unmodifiable(bytes);
    _lastAccess[assetId] = DateTime.now().toUtc();
  }

  @override
  Future<List<int>?> read(String assetId) async {
    final value = _data[assetId];
    if (value == null) return null;
    _lastAccess[assetId] = DateTime.now().toUtc();
    return List<int>.from(value);
  }

  @override
  Future<bool> delete(String assetId) async {
    _lastAccess.remove(assetId);
    return _data.remove(assetId) != null;
  }

  @override
  Future<Set<String>> listAssetIds() async => _data.keys.toSet();

  @override
  Future<Map<String, MediaAssetStats>> stats() async {
    return {
      for (final entry in _data.entries)
        entry.key: MediaAssetStats(
          sizeBytes: entry.value.length,
          lastAccessedAt:
              _lastAccess[entry.key] ?? DateTime.fromMillisecondsSinceEpoch(0),
        ),
    };
  }
}
