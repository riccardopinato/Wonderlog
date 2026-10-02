import 'cloud_models.dart';

abstract final class CloudCodec {
  static Map<String, Object?> journeyToJson(
    CloudJourney value, {
    String? ownerId,
  }) =>
      {
        'id': value.id,
        'owner_id': ownerId ?? value.ownerId,
        'local_reference_id': value.localReferenceId,
        'title': value.title,
        'destination': value.destination,
        'country': value.country,
        'description': value.description,
        'start_date': value.startDate,
        'end_date': value.endDate,
        'accent_theme': value.accentTheme,
        'cover_photo_cloud_id': value.coverPhotoCloudId,
        'created_at': value.createdAt.toUtc().millisecondsSinceEpoch,
        'updated_at': value.updatedAt.toUtc().millisecondsSinceEpoch,
        'deleted_at': value.deletedAt?.toUtc().millisecondsSinceEpoch,
        'schema_version': value.schemaVersion,
      };

  static CloudJourney journeyFromJson(Map<String, dynamic> json) =>
      CloudJourney(
        id: json['id'].toString(),
        ownerId: json['owner_id'].toString(),
        localReferenceId: json['local_reference_id']?.toString(),
        title: json['title']?.toString() ?? '',
        destination: json['destination']?.toString() ?? '',
        country: json['country']?.toString() ?? '',
        description: json['description']?.toString() ?? '',
        startDate: json['start_date']?.toString() ?? '',
        endDate: json['end_date']?.toString() ?? '',
        accentTheme: json['accent_theme']?.toString(),
        coverPhotoCloudId: json['cover_photo_cloud_id']?.toString(),
        createdAt: _date(json['created_at']),
        updatedAt: _date(json['updated_at']),
        deletedAt: _nullableDate(json['deleted_at']),
        schemaVersion: _integer(json['schema_version'], fallback: 1),
      );

  static Map<String, Object?> memoryToJson(
    CloudMemory value, {
    String? ownerId,
  }) =>
      {
        'id': value.id,
        'owner_id': ownerId ?? value.ownerId,
        'journey_cloud_id': value.journeyCloudId,
        'local_reference_id': value.localReferenceId,
        'title': value.title,
        'journal_text': value.journalText,
        'date': value.date,
        'location_name': value.locationName,
        'latitude': value.latitude,
        'longitude': value.longitude,
        'mood': value.mood,
        'tags': value.tags,
        'created_at': value.createdAt.toUtc().millisecondsSinceEpoch,
        'updated_at': value.updatedAt.toUtc().millisecondsSinceEpoch,
        'deleted_at': value.deletedAt?.toUtc().millisecondsSinceEpoch,
        'schema_version': value.schemaVersion,
      };

  static CloudMemory memoryFromJson(Map<String, dynamic> json) => CloudMemory(
        id: json['id'].toString(),
        ownerId: json['owner_id'].toString(),
        journeyCloudId: json['journey_cloud_id'].toString(),
        localReferenceId: json['local_reference_id']?.toString(),
        title: json['title']?.toString() ?? '',
        journalText: json['journal_text']?.toString() ?? '',
        date: json['date']?.toString() ?? '',
        locationName: json['location_name']?.toString(),
        latitude: _nullableDouble(json['latitude']),
        longitude: _nullableDouble(json['longitude']),
        mood: json['mood']?.toString(),
        tags: (json['tags'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(growable: false),
        createdAt: _date(json['created_at']),
        updatedAt: _date(json['updated_at']),
        deletedAt: _nullableDate(json['deleted_at']),
        schemaVersion: _integer(json['schema_version'], fallback: 1),
      );

  static Map<String, Object?> photoToJson(
    CloudAlbumPhoto value, {
    String? ownerId,
  }) =>
      {
        'id': value.id,
        'owner_id': ownerId ?? value.ownerId,
        'journey_cloud_id': value.journeyCloudId,
        'local_reference_id': value.localReferenceId,
        'remote_file_path': value.remoteFilePath,
        'file_name': value.fileName,
        'mime_type': value.mimeType,
        'captured_at': value.capturedAt?.toUtc().millisecondsSinceEpoch,
        'latitude': value.latitude,
        'longitude': value.longitude,
        'location_name': value.locationName,
        'display_order': value.displayOrder,
        'is_cover_photo': value.isCoverPhoto,
        'created_at': value.createdAt.toUtc().millisecondsSinceEpoch,
        'updated_at': value.updatedAt.toUtc().millisecondsSinceEpoch,
        'deleted_at': value.deletedAt?.toUtc().millisecondsSinceEpoch,
        'schema_version': value.schemaVersion,
      };

  static CloudAlbumPhoto photoFromJson(Map<String, dynamic> json) =>
      CloudAlbumPhoto(
        id: json['id'].toString(),
        ownerId: json['owner_id'].toString(),
        journeyCloudId: json['journey_cloud_id'].toString(),
        localReferenceId: json['local_reference_id']?.toString(),
        remoteFilePath: json['remote_file_path']?.toString(),
        fileName: json['file_name']?.toString(),
        mimeType: json['mime_type']?.toString(),
        capturedAt: _nullableDate(json['captured_at']),
        latitude: _nullableDouble(json['latitude']),
        longitude: _nullableDouble(json['longitude']),
        locationName: json['location_name']?.toString(),
        displayOrder: _integer(json['display_order']),
        isCoverPhoto: json['is_cover_photo'] == true,
        createdAt: _date(json['created_at']),
        updatedAt: _date(json['updated_at']),
        deletedAt: _nullableDate(json['deleted_at']),
        schemaVersion: _integer(json['schema_version'], fallback: 1),
      );

  static Map<String, Object?> linkToJson(
    CloudMemoryPhotoLink value, {
    String? ownerId,
  }) =>
      {
        'owner_id': ownerId ?? value.ownerId,
        'memory_cloud_id': value.memoryCloudId,
        'photo_cloud_id': value.photoCloudId,
        'display_order': value.displayOrder,
        'is_hero_photo': value.isHeroPhoto,
      };

  static CloudMemoryPhotoLink linkFromJson(Map<String, dynamic> json) =>
      CloudMemoryPhotoLink(
        ownerId: json['owner_id'].toString(),
        memoryCloudId: json['memory_cloud_id'].toString(),
        photoCloudId: json['photo_cloud_id'].toString(),
        displayOrder: _integer(json['display_order']),
        isHeroPhoto: json['is_hero_photo'] == true,
      );

  static DateTime _date(Object? raw) =>
      _nullableDate(raw) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  static DateTime? _nullableDate(Object? raw) {
    if (raw == null) return null;
    if (raw is num) {
      return DateTime.fromMillisecondsSinceEpoch(raw.toInt(), isUtc: true);
    }
    final text = raw.toString().trim();
    final millis = int.tryParse(text);
    if (millis != null) {
      return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    }
    return DateTime.tryParse(text)?.toUtc();
  }

  static int _integer(Object? raw, {int fallback = 0}) =>
      raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '') ?? fallback;

  static double? _nullableDouble(Object? raw) =>
      raw is num ? raw.toDouble() : double.tryParse(raw?.toString() ?? '');
}
