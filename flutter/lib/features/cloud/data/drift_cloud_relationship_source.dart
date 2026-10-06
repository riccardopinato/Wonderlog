import '../../../core/database/wonderlog_database.dart' as db;
import '../domain/cloud_models.dart';

final class DriftCloudRelationshipSource {
  DriftCloudRelationshipSource({
    required this.database,
    required this.currentUserId,
  });

  final db.WonderlogDatabase database;
  final String? Function() currentUserId;

  Future<List<CloudMemoryPhotoLink>> readAll() async {
    final ownerId = _requireUserId();
    final rows = await database.select(database.memoryPhotos).get();
    final result = <CloudMemoryPhotoLink>[];

    for (final row in rows) {
      final memory = await (database.select(database.memories)
            ..where((item) => item.id.equals(row.memoryId)))
          .getSingleOrNull();
      final photo = await (database.select(database.albumPhotos)
            ..where((item) => item.id.equals(row.albumPhotoId)))
          .getSingleOrNull();

      final memoryCloudId = memory?.futureCloudId?.trim();
      final photoCloudId = photo?.futureCloudId?.trim();
      if (memoryCloudId == null ||
          memoryCloudId.isEmpty ||
          photoCloudId == null ||
          photoCloudId.isEmpty) {
        continue;
      }

      result.add(
        CloudMemoryPhotoLink(
          ownerId: ownerId,
          memoryCloudId: memoryCloudId,
          photoCloudId: photoCloudId,
          displayOrder: row.displayOrder,
          isHeroPhoto: row.isHeroPhoto,
        ),
      );
    }

    return result;
  }

  String _requireUserId() {
    final value = currentUserId()?.trim();
    if (value == null || value.isEmpty) {
      throw StateError('Cloud backup requires an authenticated account.');
    }
    return value;
  }
}
