import 'package:uuid/uuid.dart';

import '../../../core/media/content_addressed_media_asset_store.dart';
import '../../../core/media/media_asset_backend.dart';
import '../../../core/media/media_asset_reference.dart';
import '../../../core/media/source_byte_reader.dart';
import '../domain/memory_models.dart';

enum PhotoImportFailureReason {
  duplicate,
  unsupportedFormat,
  tooLarge,
  readFailed,
  corrupted,
  unknown,
}

final class PhotoImportException implements Exception {
  const PhotoImportException(this.reason, this.message);

  final PhotoImportFailureReason reason;
  final String message;

  @override
  String toString() => message;
}

final class PhotoImportService {
  PhotoImportService({
    required this.mediaStore,
    required this.byteReader,
  });

  static const maxSourceBytes = 50 * 1024 * 1024;

  final MediaAssetStore mediaStore;
  final SourceByteReader byteReader;
  final Uuid _uuid = const Uuid();

  Future<List<int>?> readReference(String reference) async {
    final assetId = MediaAssetReference.tryDecode(reference);
    if (assetId != null) {
      return mediaStore.read(assetId);
    }
    try {
      return byteReader.read(reference);
    } catch (_) {
      return null;
    }
  }

  Future<AlbumPhotoEntry> importPhoto({
    required String journeyId,
    required String sourceUri,
    required int displayOrder,
    required List<AlbumPhotoEntry> existingPhotos,
    String? fileName,
    String? mimeType,
    DateTime? capturedAt,
    double? latitude,
    double? longitude,
    String locationName = '',
  }) async {
    final normalizedSource = sourceUri.trim();
    if (normalizedSource.isEmpty) {
      throw const PhotoImportException(
        PhotoImportFailureReason.readFailed,
        'Photo source is empty.',
      );
    }

    final resolvedName = _resolveFileName(fileName, normalizedSource);
    if (existingPhotos.any(
      (photo) =>
          photo.originalUri == normalizedSource ||
          (photo.fileName == resolvedName &&
              photo.originalUri == normalizedSource),
    )) {
      throw const PhotoImportException(
        PhotoImportFailureReason.duplicate,
        'Photo is already in this album.',
      );
    }

    late final List<int> bytes;
    try {
      bytes = await byteReader.read(normalizedSource);
    } catch (error) {
      throw PhotoImportException(
        PhotoImportFailureReason.readFailed,
        'Unable to read photo: ' + error.toString(),
      );
    }

    if (bytes.isEmpty) {
      throw const PhotoImportException(
        PhotoImportFailureReason.corrupted,
        'Photo is empty or corrupted.',
      );
    }
    if (bytes.length > maxSourceBytes) {
      throw const PhotoImportException(
        PhotoImportFailureReason.tooLarge,
        'Photo is too large to import safely.',
      );
    }

    final detectedMime = _detectMime(bytes, mimeType);
    if (detectedMime == null) {
      throw const PhotoImportException(
        PhotoImportFailureReason.unsupportedFormat,
        'Unsupported image format.',
      );
    }

    final assetId = await mediaStore.putOriginal(
      bytes,
      mimeType: detectedMime,
    );
    final reference = MediaAssetReference.encode(assetId);
    final now = DateTime.now().toUtc();

    return AlbumPhotoEntry(
      id: 'photo_' + _uuid.v4(),
      journeyId: journeyId,
      localUri: reference,
      thumbnailUri: reference,
      originalUri: normalizedSource,
      fileName: resolvedName,
      mimeType: detectedMime,
      width: 0,
      height: 0,
      fileSize: bytes.length,
      createdAt: now,
      updatedAt: now,
      capturedAt: capturedAt ?? now,
      gpsLatitude: latitude,
      gpsLongitude: longitude,
      locationName: locationName,
      favorite: false,
      isCoverPhoto: false,
      displayOrder: displayOrder,
      syncStatus: 'LOCAL_ONLY',
    );
  }

  String _resolveFileName(String? provided, String source) {
    final normalized = provided?.trim();
    if (normalized != null && normalized.isNotEmpty) return normalized;

    final uri = Uri.tryParse(source);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last.trim();
      if (last.isNotEmpty) return last;
    }
    return 'photo.jpg';
  }

  String? _detectMime(List<int> bytes, String? declared) {
    final normalized = declared?.trim().toLowerCase();
    if (normalized != null &&
        normalized.startsWith('image/') &&
        _supportedMime.contains(normalized)) {
      return normalized;
    }

    if (bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff) {
      return 'image/jpeg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4e &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    if (bytes.length >= 12 &&
        String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
        String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP') {
      return 'image/webp';
    }
    return null;
  }

  static const _supportedMime = {
    'image/jpeg',
    'image/jpg',
    'image/png',
    'image/webp',
  };
}

Future<PhotoImportService> createPlatformPhotoImportService() async {
  final backend = await createPlatformMediaAssetBackend();
  return PhotoImportService(
    mediaStore: ContentAddressedMediaAssetStore(backend),
    byteReader: const PlatformSourceByteReader(),
  );
}
