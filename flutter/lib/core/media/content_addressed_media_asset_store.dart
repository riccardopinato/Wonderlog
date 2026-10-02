import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'media_asset_backend.dart';

final class ContentAddressedMediaAssetStore implements MediaAssetStore {
  ContentAddressedMediaAssetStore(this.backend);

  final MediaAssetBackend backend;

  @override
  Future<String> putOriginal(
    List<int> bytes, {
    String? mimeType,
  }) async {
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Media cannot be empty.');
    }
    final assetId = contentAssetId(bytes);
    final existing = await backend.read(assetId);
    if (existing == null) {
      await backend.write(assetId, bytes);
    } else if (!_matches(assetId, existing)) {
      throw StateError('Existing media asset failed integrity validation.');
    }
    return assetId;
  }

  @override
  Future<String> putNamed(
    String namespace,
    String key,
    List<int> bytes,
  ) async {
    final safeNamespace = _safeToken(namespace, 'namespace');
    final safeKey = _safeToken(key, 'key');
    if (bytes.isEmpty) {
      throw ArgumentError.value(bytes, 'bytes', 'Media cannot be empty.');
    }

    final digest = sha256.convert(bytes).toString();
    final assetId =
        'named_' + safeNamespace + '_' + safeKey + '_sha256_' + digest;
    await backend.write(assetId, bytes);
    return assetId;
  }

  @override
  Future<List<int>?> read(String assetId) async {
    final bytes = await backend.read(assetId);
    if (bytes == null) return null;
    if (assetId.startsWith('sha256_') && !_matches(assetId, bytes)) {
      return null;
    }
    return bytes;
  }

  @override
  Future<bool> delete(String assetId) => backend.delete(assetId);

  @override
  Future<int> prune(Set<String> referencedAssetIds) async {
    final stored = await backend.listAssetIds();
    var deleted = 0;
    for (final assetId in stored) {
      if (referencedAssetIds.contains(assetId)) continue;
      if (await backend.delete(assetId)) deleted++;
    }
    return deleted;
  }

  @override
  Future<Set<String>> listStoredAssetIds() => backend.listAssetIds();

  bool _matches(String assetId, List<int> bytes) =>
      contentAssetId(bytes) == assetId;

  String _safeToken(String raw, String name) {
    final value = raw.trim();
    if (value.isEmpty ||
        !RegExp(r'^[a-zA-Z0-9_.-]{1,96}$').hasMatch(value)) {
      throw ArgumentError.value(raw, name, 'Unsafe media token.');
    }
    return value;
  }
}

String contentAssetId(List<int> bytes) =>
    'sha256_' + sha256.convert(bytes).toString();

String contentAssetIdForText(String value) =>
    contentAssetId(utf8.encode(value));
