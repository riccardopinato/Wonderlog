import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'cloud_backup_config.dart';
import 'cloud_local_data_source.dart';
import 'cloud_models.dart';
import 'cloud_provider.dart';
import 'sync_queue_store.dart';

typedef CloudAssetReader = Future<Uint8List?> Function(String reference);

final class CloudSyncRepository {
  CloudSyncRepository({
    required this.cloudProvider,
    required this.queueStore,
    required this.localDataSource,
    required this.assetReader,
  });

  final CloudProvider cloudProvider;
  final SyncQueueStore queueStore;
  final CloudLocalDataSource localDataSource;
  final CloudAssetReader assetReader;
  final Uuid _uuid = const Uuid();

  Future<void> enqueueJourney(String journeyId) =>
      _enqueue(SyncEntityType.journey, journeyId);

  Future<void> enqueueMemory(String memoryId) =>
      _enqueue(SyncEntityType.memory, memoryId);

  Future<void> enqueuePhoto(String photoId) =>
      _enqueue(SyncEntityType.albumPhoto, photoId);

  Future<void> enqueueDelete(
    SyncEntityType entityType,
    String localId,
  ) =>
      _enqueue(
        entityType,
        localId,
        operation: SyncOperation.delete,
      );

  Future<int> pendingCount() async =>
      (await queueStore.nextBatch(limit: 5000)).length;

  Future<SyncSummary> syncNow() async {
    if (!await cloudProvider.isAuthenticated()) {
      throw StateError('Cloud backup requires an authenticated account.');
    }

    final items = await queueStore.nextBatch(
      limit: CloudBackupConfig.syncBatchSize,
    );
    var uploaded = 0;
    var deleted = 0;
    var failures = 0;

    for (final item in items) {
      try {
        switch (item.operation) {
          case SyncOperation.createOrUpdate:
            await _processUpload(item);
            uploaded++;
          case SyncOperation.delete:
            await _processDelete(item);
            deleted++;
        }
        await queueStore.remove(item.id);
      } catch (error) {
        failures++;
        await queueStore.markFailure(
          id: item.id,
          error: error.toString(),
        );
      }
    }

    return SyncSummary(
      uploaded: uploaded,
      deleted: deleted,
      failures: failures,
    );
  }

  Future<SyncSummary> syncAllPending({
    required bool includePhotos,
  }) async {
    for (final id in await localDataSource.getPendingJourneyIds()) {
      await enqueueJourney(id);
    }

    final journeys = await syncNow();

    for (final id in await localDataSource.getPendingMemoryIds()) {
      await enqueueMemory(id);
    }
    if (includePhotos) {
      for (final id in await localDataSource.getPendingPhotoIds()) {
        await enqueuePhoto(id);
      }
    }

    final content = await syncNow();
    return SyncSummary(
      uploaded: journeys.uploaded + content.uploaded,
      downloaded: journeys.downloaded + content.downloaded,
      deleted: journeys.deleted + content.deleted,
      conflicts: journeys.conflicts + content.conflicts,
      failures: journeys.failures + content.failures,
    );
  }

  Future<void> _enqueue(
    SyncEntityType type,
    String localId, {
    SyncOperation operation = SyncOperation.createOrUpdate,
  }) =>
      queueStore.enqueue(
        SyncQueueItem(
          id: _uuid.v4(),
          entityType: type,
          localEntityId: localId,
          operation: operation,
          createdAt: DateTime.now().toUtc(),
        ),
      );

  Future<void> _processUpload(SyncQueueItem item) async {
    switch (item.entityType) {
      case SyncEntityType.journey:
        final payload =
            await localDataSource.getJourneyForCloud(item.localEntityId);
        if (payload == null) throw StateError('Journey not found.');
        final cloud = await cloudProvider.uploadJourney(payload);
        await localDataSource.markJourneySynced(
          item.localEntityId,
          cloud.id,
        );

      case SyncEntityType.memory:
        final payload =
            await localDataSource.getMemoryForCloud(item.localEntityId);
        if (payload == null) {
          throw StateError(
            'Memory not found or its Journey is not synced yet.',
          );
        }
        final cloud = await cloudProvider.uploadMemory(payload);
        await localDataSource.markMemorySynced(
          item.localEntityId,
          cloud.id,
        );

      case SyncEntityType.albumPhoto:
        final payload =
            await localDataSource.getPhotoForCloud(item.localEntityId);
        if (payload == null) {
          throw StateError(
            'Photo not found or its Journey is not synced yet.',
          );
        }

        final reference = await localDataSource.getPhotoLocalReference(
          item.localEntityId,
        );
        String? remotePath;
        if (reference != null && reference.trim().isNotEmpty) {
          final bytes = await assetReader(reference);
          if (bytes != null && bytes.isNotEmpty) {
            remotePath = await localDataSource.buildRemotePhotoPath(
              item.localEntityId,
            );
            await cloudProvider.uploadPhotoFile(bytes, remotePath);
          }
        }

        final cloud = await cloudProvider.uploadPhotoMetadata(
          CloudAlbumPhoto(
            id: payload.id,
            ownerId: payload.ownerId,
            journeyCloudId: payload.journeyCloudId,
            localReferenceId: payload.localReferenceId,
            remoteFilePath: remotePath,
            fileName: payload.fileName,
            mimeType: payload.mimeType,
            capturedAt: payload.capturedAt,
            latitude: payload.latitude,
            longitude: payload.longitude,
            locationName: payload.locationName,
            displayOrder: payload.displayOrder,
            isCoverPhoto: payload.isCoverPhoto,
            createdAt: payload.createdAt,
            updatedAt: payload.updatedAt,
            deletedAt: payload.deletedAt,
            schemaVersion: payload.schemaVersion,
          ),
        );
        await localDataSource.markPhotoSynced(
          item.localEntityId,
          cloud.id,
          cloud.remoteFilePath,
        );
    }
  }

  Future<void> _processDelete(SyncQueueItem item) async {
    switch (item.entityType) {
      case SyncEntityType.journey:
        final cloudId =
            await localDataSource.getJourneyCloudId(item.localEntityId);
        if (cloudId != null) await cloudProvider.deleteJourney(cloudId);

      case SyncEntityType.memory:
        final cloudId =
            await localDataSource.getMemoryCloudId(item.localEntityId);
        if (cloudId != null) await cloudProvider.deleteMemory(cloudId);

      case SyncEntityType.albumPhoto:
        final info = await localDataSource.getPhotoCloudDeleteInfo(
          item.localEntityId,
        );
        if (info != null) {
          await cloudProvider.deletePhoto(
            info.cloudId,
            info.remoteFilePath,
          );
        }
    }
  }
}
