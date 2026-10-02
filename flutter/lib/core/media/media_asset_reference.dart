abstract final class MediaAssetReference {
  static const scheme = 'media://';

  static String encode(String assetId) {
    final normalized = assetId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(assetId, 'assetId', 'Asset id is required.');
    }
    return scheme + normalized;
  }

  static String? tryDecode(String reference) {
    final normalized = reference.trim();
    if (!normalized.startsWith(scheme)) return null;
    final value = normalized.substring(scheme.length);
    return value.isEmpty ? null : value;
  }
}
