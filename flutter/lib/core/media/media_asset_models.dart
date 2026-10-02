enum MediaAssetKind {
  original,
  thumbnail,
  derivative,
}

final class MediaAssetDescriptor {
  const MediaAssetDescriptor({
    required this.assetId,
    required this.kind,
    this.mimeType,
    this.originalAssetId,
  });

  final String assetId;
  final MediaAssetKind kind;
  final String? mimeType;
  final String? originalAssetId;
}

final class MediaAssetStats {
  const MediaAssetStats({
    required this.sizeBytes,
    required this.lastAccessedAt,
  });

  final int sizeBytes;
  final DateTime lastAccessedAt;
}
