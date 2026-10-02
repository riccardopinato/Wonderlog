enum Mood {
  happy('😊', 'Happy'),
  calm('🧘', 'Calm'),
  adventure('🧗', 'Adventure'),
  romantic('💖', 'Romantic'),
  food('🍕', 'Food'),
  nature('🌲', 'Nature'),
  nostalgic('🎞️', 'Nostalgic'),
  adventurous('🧗', 'Adventurous'),
  serene('🧘', 'Serene'),
  energetic('⚡', 'Energetic'),
  dreamy('🌙', 'Dreamy');

  const Mood(this.emoji, this.label);
  final String emoji;
  final String label;
}

final class GeoCoordinate {
  const GeoCoordinate(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

final class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.journeyId,
    required this.title,
    required this.journalText,
    required this.locationName,
    required this.date,
    required this.mood,
    required this.tags,
    this.latitude,
    this.longitude,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
    this.displayOrder = 0,
    this.syncStatus = 'LOCAL_ONLY',
    this.futureCloudId,
  });

  final String id;
  final String journeyId;
  final String title;
  final String journalText;
  final String locationName;
  final DateTime date;
  final Mood mood;
  final List<String> tags;
  final double? latitude;
  final double? longitude;
  final bool favorite;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int displayOrder;
  final String syncStatus;
  final String? futureCloudId;

  GeoCoordinate? get coordinate =>
      latitude == null || longitude == null
          ? null
          : GeoCoordinate(latitude!, longitude!);
}

final class AlbumPhotoEntry {
  const AlbumPhotoEntry({
    required this.id,
    required this.journeyId,
    required this.localUri,
    required this.thumbnailUri,
    required this.originalUri,
    required this.fileName,
    required this.mimeType,
    required this.width,
    required this.height,
    required this.fileSize,
    required this.createdAt,
    required this.updatedAt,
    this.capturedAt,
    this.gpsLatitude,
    this.gpsLongitude,
    this.locationName = '',
    this.favorite = false,
    this.isCoverPhoto = false,
    this.displayOrder = 0,
    this.syncStatus = 'LOCAL_ONLY',
    this.futureCloudId,
  });

  final String id;
  final String journeyId;
  final String localUri;
  final String thumbnailUri;
  final String originalUri;
  final String fileName;
  final String mimeType;
  final int width;
  final int height;
  final int fileSize;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? capturedAt;
  final double? gpsLatitude;
  final double? gpsLongitude;
  final String locationName;
  final bool favorite;
  final bool isCoverPhoto;
  final int displayOrder;
  final String syncStatus;
  final String? futureCloudId;

  GeoCoordinate? get gpsCoordinate =>
      gpsLatitude == null || gpsLongitude == null
          ? null
          : GeoCoordinate(gpsLatitude!, gpsLongitude!);
}

final class MemoryAttachment {
  const MemoryAttachment({
    required this.id,
    required this.memoryId,
    required this.localUri,
    required this.mimeType,
    required this.attachmentType,
    required this.createdAt,
    required this.syncStatus,
    this.originalName,
  });

  final String id;
  final String memoryId;
  final String localUri;
  final String? originalName;
  final String mimeType;
  final String attachmentType;
  final DateTime createdAt;
  final String syncStatus;
}

final class MemoryWithPhotos {
  const MemoryWithPhotos({
    required this.memory,
    required this.photos,
    this.attachments = const [],
  });

  final MemoryEntry memory;
  final List<AlbumPhotoEntry> photos;
  final List<MemoryAttachment> attachments;
}
