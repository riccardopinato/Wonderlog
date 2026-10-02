import 'dart:typed_data';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/wonderlog_database.dart' as db;
import '../domain/cloud_merge_engine.dart';
import '../domain/cloud_models.dart';
import '../domain/cloud_provider.dart';
import '../domain/restore_models.dart';
import '../domain/restored_photo_storage.dart';

typedef RestoreProgressCallback = Future<void> Function(
  RestoreProgress progress,
);

final class CloudRestoreRepository {
  CloudRestoreRepository({
    required this.database,
    required this.cloudProvider,
    required this.photoStorage,
  });

  final db.WonderlogDatabase database;
  final CloudProvider cloudProvider;
  final RestoredPhotoStorage photoStorage;
  final Uuid _uuid = const Uuid();

  Future<RestoreSummary> restoreEverything({
    RestoreProgressCallback? onProgress,
  }) async {
    if (!await cloudProvider.isAuthenticated()) {
      throw StateError('Sign in before restoring your cloud backup.');
    }

    await _emit(
      onProgress,
      const RestoreProgress(
        phase: RestorePhase.preparing,
        message: 'Checking your cloud backup…',
      ),
    );

    final journeys = await cloudProvider.fetchJourneys(null);
    final memories = await cloudProvider.fetchMemories(null);
    final photos = await cloudProvider.fetchPhotos(null);
    final links = await cloudProvider.fetchMemoryPhotoLinks();

    var journeysInserted = 0;
    var journeysUpdated = 0;
    var memoriesInserted = 0;
    var memoriesUpdated = 0;
    var photosInserted = 0;
    var photosUpdated = 0;
    var downloads = 0;
    var restoredLinks = 0;
    var conflicts = 0;
    var skipped = 0;
    var failures = 0;

    final journeyIdMap = <String, String>{};
    final memoryIdMap = <String, String>{};
    final photoIdMap = <String, String>{};

    for (var index = 0; index < journeys.length; index++) {
      final cloud = journeys[index];
      await _emit(
        onProgress,
        RestoreProgress(
          phase: RestorePhase.journeys,
          current: index + 1,
          total: journeys.length,
          message: 'Restoring Journeys…',
        ),
      );

      try {
        final existing = await _findTrip(cloud);
        final decision = CloudMergeEngine.decide(
          localUpdatedAt: existing == null ? null : _date(existing.updatedAt),
          localSyncStatus: existing?.syncStatus,
          cloudUpdatedAt: cloud.updatedAt,
          cloudDeletedAt: cloud.deletedAt,
        );

        switch (decision) {
          case CloudMergeDecision.insertCloud:
            final localId = _usableLocalReference(cloud.localReferenceId) ??
                'trip_' + _uuid.v4();
            await database.into(database.trips).insertOnConflictUpdate(
                  _tripCompanion(
                    cloud: cloud,
                    localId: localId,
                    existing: null,
                  ),
                );
            journeyIdMap[cloud.id] = localId;
            journeysInserted++;

          case CloudMergeDecision.applyCloud:
            if (existing != null) {
              await database.into(database.trips).insertOnConflictUpdate(
                    _tripCompanion(
                      cloud: cloud,
                      localId: existing.id,
                      existing: existing,
                    ),
                  );
              journeyIdMap[cloud.id] = existing.id;
              journeysUpdated++;
            }

          case CloudMergeDecision.keepLocal:
          case CloudMergeDecision.skip:
            if (existing != null) journeyIdMap[cloud.id] = existing.id;
            skipped++;

          case CloudMergeDecision.conflict:
            if (existing != null) {
              await (database.update(database.trips)
                    ..where((row) => row.id.equals(existing.id)))
                  .write(
                const db.TripsCompanion(
                  syncStatus: Value('CONFLICT'),
                ),
              );
              journeyIdMap[cloud.id] = existing.id;
            }
            conflicts++;
        }
      } catch (_) {
        failures++;
      }
    }

    for (var index = 0; index < memories.length; index++) {
      final cloud = memories[index];
      await _emit(
        onProgress,
        RestoreProgress(
          phase: RestorePhase.memories,
          current: index + 1,
          total: memories.length,
          message: 'Restoring Memories…',
        ),
      );

      try {
        final journeyLocalId = journeyIdMap[cloud.journeyCloudId];
        if (journeyLocalId == null) {
          failures++;
          continue;
        }

        final existing = await _findMemory(cloud);
        final decision = CloudMergeEngine.decide(
          localUpdatedAt: existing == null ? null : _date(existing.updatedAt),
          localSyncStatus: existing?.syncStatus,
          cloudUpdatedAt: cloud.updatedAt,
          cloudDeletedAt: cloud.deletedAt,
        );

        switch (decision) {
          case CloudMergeDecision.insertCloud:
            final localId = _usableLocalReference(cloud.localReferenceId) ??
                'mem_' + _uuid.v4();
            await database.into(database.memories).insertOnConflictUpdate(
                  _memoryCompanion(
                    cloud: cloud,
                    localId: localId,
                    journeyLocalId: journeyLocalId,
                    existing: null,
                  ),
                );
            memoryIdMap[cloud.id] = localId;
            memoriesInserted++;

          case CloudMergeDecision.applyCloud:
            if (existing != null) {
              await database.into(database.memories).insertOnConflictUpdate(
                    _memoryCompanion(
                      cloud: cloud,
                      localId: existing.id,
                      journeyLocalId: journeyLocalId,
                      existing: existing,
                    ),
                  );
              memoryIdMap[cloud.id] = existing.id;
              memoriesUpdated++;
            }

          case CloudMergeDecision.keepLocal:
          case CloudMergeDecision.skip:
            if (existing != null) memoryIdMap[cloud.id] = existing.id;
            skipped++;

          case CloudMergeDecision.conflict:
            if (existing != null) {
              await (database.update(database.memories)
                    ..where((row) => row.id.equals(existing.id)))
                  .write(
                const db.MemoriesCompanion(
                  syncStatus: Value('CONFLICT'),
                ),
              );
              memoryIdMap[cloud.id] = existing.id;
            }
            conflicts++;
        }
      } catch (_) {
        failures++;
      }
    }

    for (var index = 0; index < photos.length; index++) {
      final cloud = photos[index];
      await _emit(
        onProgress,
        RestoreProgress(
          phase: RestorePhase.photos,
          current: index + 1,
          total: photos.length,
          message: 'Restoring photos…',
        ),
      );

      try {
        final journeyLocalId = journeyIdMap[cloud.journeyCloudId];
        if (journeyLocalId == null) {
          failures++;
          continue;
        }

        final existing = await _findPhoto(cloud);
        final decision = CloudMergeEngine.decide(
          localUpdatedAt: existing == null ? null : _date(existing.updatedAt),
          localSyncStatus: existing?.syncStatus,
          cloudUpdatedAt: cloud.updatedAt,
          cloudDeletedAt: cloud.deletedAt,
        );

        switch (decision) {
          case CloudMergeDecision.insertCloud:
          case CloudMergeDecision.applyCloud:
            final localId = existing?.id ??
                _usableLocalReference(cloud.localReferenceId) ??
                'photo_' + _uuid.v4();

            RestoredPhotoFiles? files;
            final remotePath = cloud.remoteFilePath?.trim();
            if (remotePath != null && remotePath.isNotEmpty) {
              final Uint8List bytes =
                  await cloudProvider.downloadPhotoFile(remotePath);
              files = await photoStorage.save(
                journeyId: journeyLocalId,
                photoId: localId,
                bytes: bytes,
                fileName: cloud.fileName,
                mimeType: cloud.mimeType,
              );
              downloads++;
            }

            await database.into(database.albumPhotos).insertOnConflictUpdate(
                  _photoCompanion(
                    cloud: cloud,
                    localId: localId,
                    journeyLocalId: journeyLocalId,
                    files: files,
                    existing: existing,
                  ),
                );
            photoIdMap[cloud.id] = localId;
            if (existing == null) {
              photosInserted++;
            } else {
              photosUpdated++;
            }

          case CloudMergeDecision.keepLocal:
          case CloudMergeDecision.skip:
            if (existing != null) photoIdMap[cloud.id] = existing.id;
            skipped++;

          case CloudMergeDecision.conflict:
            if (existing != null) {
              await (database.update(database.albumPhotos)
                    ..where((row) => row.id.equals(existing.id)))
                  .write(
                const db.AlbumPhotosCompanion(
                  syncStatus: Value('CONFLICT'),
                ),
              );
              photoIdMap[cloud.id] = existing.id;
            }
            conflicts++;
        }
      } catch (_) {
        failures++;
      }
    }

    await _emit(
      onProgress,
      const RestoreProgress(
        phase: RestorePhase.relationships,
        message: 'Restoring Memory albums…',
      ),
    );

    for (final link in links) {
      final memoryLocalId = memoryIdMap[link.memoryCloudId];
      final photoLocalId = photoIdMap[link.photoCloudId];
      if (memoryLocalId == null || photoLocalId == null) continue;

      try {
        await database.into(database.memoryPhotos).insertOnConflictUpdate(
              db.MemoryPhotosCompanion.insert(
                memoryId: memoryLocalId,
                albumPhotoId: photoLocalId,
                displayOrder: Value(link.displayOrder),
                isHeroPhoto: Value(link.isHeroPhoto),
              ),
            );
        restoredLinks++;
      } catch (_) {
        failures++;
      }
    }

    await _emit(
      onProgress,
      const RestoreProgress(
        phase: RestorePhase.complete,
        message: 'Restore complete.',
      ),
    );

    return RestoreSummary(
      journeysInserted: journeysInserted,
      journeysUpdated: journeysUpdated,
      memoriesInserted: memoriesInserted,
      memoriesUpdated: memoriesUpdated,
      photosInserted: photosInserted,
      photosUpdated: photosUpdated,
      photoFilesDownloaded: downloads,
      memoryPhotoLinksRestored: restoredLinks,
      conflicts: conflicts,
      skipped: skipped,
      failures: failures,
    );
  }

  Future<db.Trip?> _findTrip(CloudJourney cloud) async {
    final byCloud = await (database.select(database.trips)
          ..where((row) => row.futureCloudId.equals(cloud.id)))
        .getSingleOrNull();
    if (byCloud != null) return byCloud;

    final local = _usableLocalReference(cloud.localReferenceId);
    if (local == null) return null;
    return (database.select(database.trips)
          ..where((row) => row.id.equals(local)))
        .getSingleOrNull();
  }

  Future<db.Memory?> _findMemory(CloudMemory cloud) async {
    final byCloud = await (database.select(database.memories)
          ..where((row) => row.futureCloudId.equals(cloud.id)))
        .getSingleOrNull();
    if (byCloud != null) return byCloud;

    final local = _usableLocalReference(cloud.localReferenceId);
    if (local == null) return null;
    return (database.select(database.memories)
          ..where((row) => row.id.equals(local)))
        .getSingleOrNull();
  }

  Future<db.AlbumPhoto?> _findPhoto(CloudAlbumPhoto cloud) async {
    final byCloud = await (database.select(database.albumPhotos)
          ..where((row) => row.futureCloudId.equals(cloud.id)))
        .getSingleOrNull();
    if (byCloud != null) return byCloud;

    final local = _usableLocalReference(cloud.localReferenceId);
    if (local == null) return null;
    return (database.select(database.albumPhotos)
          ..where((row) => row.id.equals(local)))
        .getSingleOrNull();
  }

  db.TripsCompanion _tripCompanion({
    required CloudJourney cloud,
    required String localId,
    required db.Trip? existing,
  }) =>
      db.TripsCompanion.insert(
        id: localId,
        destinationName: cloud.destination,
        country: Value(cloud.country),
        startDate: cloud.startDate,
        endDate: cloud.endDate,
        coverImage: Value(existing?.coverImage ?? ''),
        description: Value(cloud.description),
        accentGradientIndex: Value(existing?.accentGradientIndex ?? 0),
        latitude: Value(existing?.latitude ?? 0),
        longitude: Value(existing?.longitude ?? 0),
        title: cloud.title,
        destination: cloud.destination,
        coverPhotoId: Value(existing?.coverPhotoId ?? ''),
        accentTheme: Value(
          cloud.accentTheme ?? existing?.accentTheme ?? 'Preset_0',
        ),
        createdAt: cloud.createdAt.toUtc().millisecondsSinceEpoch,
        updatedAt: cloud.updatedAt.toUtc().millisecondsSinceEpoch,
        favorite: Value(existing?.favorite ?? false),
        archived: Value(existing?.archived ?? false),
        statistics: Value(existing?.statistics ?? ''),
        futureCloudId: Value(cloud.id),
        syncStatus: const Value('SYNCED'),
      );

  db.MemoriesCompanion _memoryCompanion({
    required CloudMemory cloud,
    required String localId,
    required String journeyLocalId,
    required db.Memory? existing,
  }) =>
      db.MemoriesCompanion.insert(
        id: localId,
        tripId: journeyLocalId,
        journeyId: journeyLocalId,
        title: cloud.title,
        note: Value(cloud.journalText),
        journalText: Value(cloud.journalText),
        image: Value(existing?.image ?? ''),
        locationName: Value(cloud.locationName ?? ''),
        latitude: Value(cloud.latitude),
        longitude: Value(cloud.longitude),
        date: cloud.date,
        mood: Value(_safeMood(cloud.mood)),
        tagsJson: Value(_encodeTags(cloud.tags)),
        favorite: Value(existing?.favorite ?? false),
        createdAt: cloud.createdAt.toUtc().millisecondsSinceEpoch,
        updatedAt: cloud.updatedAt.toUtc().millisecondsSinceEpoch,
        displayOrder: Value(existing?.displayOrder ?? 0),
        syncStatus: const Value('SYNCED'),
        futureCloudId: Value(cloud.id),
      );

  db.AlbumPhotosCompanion _photoCompanion({
    required CloudAlbumPhoto cloud,
    required String localId,
    required String journeyLocalId,
    required RestoredPhotoFiles? files,
    required db.AlbumPhoto? existing,
  }) {
    final originalPath =
        files?.originalPath ?? existing?.localUri ?? '';
    final thumbnailPath =
        files?.thumbnailPath ?? existing?.thumbnailUri ?? originalPath;

    return db.AlbumPhotosCompanion.insert(
      id: localId,
      journeyId: journeyLocalId,
      localUri: originalPath,
      thumbnailUri: Value(thumbnailPath),
      originalUri: Value(originalPath),
      fileName: Value(
        cloud.fileName ?? existing?.fileName ?? localId + '.jpg',
      ),
      mimeType: Value(
        cloud.mimeType ?? existing?.mimeType ?? 'image/jpeg',
      ),
      width: Value(files?.width ?? existing?.width ?? 0),
      height: Value(files?.height ?? existing?.height ?? 0),
      fileSize: Value(files?.fileSize ?? existing?.fileSize ?? 0),
      createdAt: cloud.createdAt.toUtc().millisecondsSinceEpoch,
      updatedAt: cloud.updatedAt.toUtc().millisecondsSinceEpoch,
      capturedAt:
          Value(cloud.capturedAt?.toUtc().millisecondsSinceEpoch),
      gpsLatitude: Value(cloud.latitude),
      gpsLongitude: Value(cloud.longitude),
      locationName: Value(cloud.locationName ?? ''),
      favorite: Value(existing?.favorite ?? false),
      isCoverPhoto: Value(cloud.isCoverPhoto),
      displayOrder: Value(cloud.displayOrder),
      syncStatus: const Value('SYNCED'),
      futureCloudId: Value(cloud.id),
    );
  }

  String? _usableLocalReference(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  DateTime _date(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

  String _safeMood(String? value) {
    const allowed = {
      'HAPPY',
      'CALM',
      'ADVENTURE',
      'ROMANTIC',
      'FOOD',
      'NATURE',
      'NOSTALGIC',
      'ADVENTUROUS',
      'SERENE',
      'ENERGETIC',
      'DREAMY',
    };
    final normalized = value?.trim().toUpperCase();
    return normalized != null && allowed.contains(normalized)
        ? normalized
        : 'HAPPY';
  }

  String _encodeTags(List<String> tags) =>
      '[' +
      tags
          .map(
            (value) =>
                '"' + value.replaceAll(r'\', r'\\').replaceAll('"', r'\"') + '"',
          )
          .join(',') +
      ']';

  Future<void> _emit(
    RestoreProgressCallback? callback,
    RestoreProgress progress,
  ) async {
    if (callback != null) await callback(progress);
  }
}
