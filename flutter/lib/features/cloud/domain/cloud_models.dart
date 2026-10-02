enum SyncStatus {
  localOnly,
  pendingUpload,
  synced,
  pendingDelete,
  conflict,
  error,
}

enum SyncEntityType { journey, memory, albumPhoto }

enum SyncOperation { createOrUpdate, delete }

final class SyncQueueItem {
  const SyncQueueItem({
    required this.id,
    required this.entityType,
    required this.localEntityId,
    required this.operation,
    required this.createdAt,
    this.attemptCount = 0,
    this.lastError,
  });

  final String id;
  final SyncEntityType entityType;
  final String localEntityId;
  final SyncOperation operation;
  final DateTime createdAt;
  final int attemptCount;
  final String? lastError;
}

final class SyncSummary {
  const SyncSummary({
    this.uploaded = 0,
    this.downloaded = 0,
    this.deleted = 0,
    this.conflicts = 0,
    this.failures = 0,
  });

  final int uploaded;
  final int downloaded;
  final int deleted;
  final int conflicts;
  final int failures;
}

final class CloudJourney {
  const CloudJourney({
    required this.id,
    required this.ownerId,
    required this.localReferenceId,
    required this.title,
    required this.destination,
    required this.country,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.accentTheme,
    required this.coverPhotoCloudId,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.schemaVersion = 1,
  });

  final String id;
  final String ownerId;
  final String? localReferenceId;
  final String title;
  final String destination;
  final String country;
  final String description;
  final String startDate;
  final String endDate;
  final String? accentTheme;
  final String? coverPhotoCloudId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int schemaVersion;
}

final class CloudMemory {
  const CloudMemory({
    required this.id,
    required this.ownerId,
    required this.journeyCloudId,
    required this.localReferenceId,
    required this.title,
    required this.journalText,
    required this.date,
    required this.locationName,
    required this.latitude,
    required this.longitude,
    required this.mood,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.schemaVersion = 1,
  });

  final String id;
  final String ownerId;
  final String journeyCloudId;
  final String? localReferenceId;
  final String title;
  final String journalText;
  final String date;
  final String? locationName;
  final double? latitude;
  final double? longitude;
  final String? mood;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int schemaVersion;
}

final class CloudAlbumPhoto {
  const CloudAlbumPhoto({
    required this.id,
    required this.ownerId,
    required this.journeyCloudId,
    required this.localReferenceId,
    required this.remoteFilePath,
    required this.fileName,
    required this.mimeType,
    required this.capturedAt,
    required this.latitude,
    required this.longitude,
    required this.locationName,
    required this.displayOrder,
    required this.isCoverPhoto,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    this.schemaVersion = 1,
  });

  final String id;
  final String ownerId;
  final String journeyCloudId;
  final String? localReferenceId;
  final String? remoteFilePath;
  final String? fileName;
  final String? mimeType;
  final DateTime? capturedAt;
  final double? latitude;
  final double? longitude;
  final String? locationName;
  final int displayOrder;
  final bool isCoverPhoto;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int schemaVersion;
}


final class CloudMemoryPhotoLink {
  const CloudMemoryPhotoLink({
    required this.ownerId,
    required this.memoryCloudId,
    required this.photoCloudId,
    required this.displayOrder,
    required this.isHeroPhoto,
  });

  final String ownerId;
  final String memoryCloudId;
  final String photoCloudId;
  final int displayOrder;
  final bool isHeroPhoto;
}
