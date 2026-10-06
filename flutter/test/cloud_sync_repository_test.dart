import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/features/cloud/data/drift_cloud_local_data_source.dart';
import 'package:wonderlog/features/cloud/data/drift_sync_queue_store.dart';
import 'package:wonderlog/features/cloud/domain/cloud_models.dart';
import 'package:wonderlog/features/cloud/domain/cloud_provider.dart';
import 'package:wonderlog/features/cloud/domain/cloud_sync_repository.dart';
import 'package:wonderlog/features/memories/data/drift_wonderlog_repository.dart';

void main() {
  late WonderlogDatabase database;
  late DriftWonderlogRepository localRepository;
  late DriftSyncQueueStore queueStore;
  late _RecordingCloudProvider provider;
  late CloudSyncRepository cloudRepository;

  setUp(() {
    database = WonderlogDatabase(NativeDatabase.memory());
    localRepository = DriftWonderlogRepository(database);
    queueStore = DriftSyncQueueStore(database);
    provider = _RecordingCloudProvider();
    cloudRepository = CloudSyncRepository(
      cloudProvider: provider,
      queueStore: queueStore,
      localDataSource: DriftCloudLocalDataSource(
        database: database,
        currentUserId: () => 'owner-1',
      ),
      assetReader: (_) async => null,
    );
  });

  tearDown(() => database.close());

  test('syncAllPending drains more than one queue batch', () async {
    for (var index = 0; index < 60; index++) {
      await localRepository.createJourney(
        title: 'Journey ' + index.toString(),
        destination: 'Destination ' + index.toString(),
        startDate: DateTime.utc(2026, 1, 1),
        endDate: DateTime.utc(2026, 1, 2),
      );
    }

    final result = await cloudRepository.syncAllPending(
      includePhotos: false,
    );

    expect(result.uploaded, 60);
    expect(result.failures, 0);
    expect(provider.uploadedJourneys, hasLength(60));
    expect(await cloudRepository.pendingCount(), 0);
  });

  test('delete replaces an unsynced upload for the same entity', () async {
    final journey = await localRepository.createJourney(
      title: 'Never upload me',
      destination: 'Vicenza',
      startDate: DateTime.utc(2026, 3, 1),
      endDate: DateTime.utc(2026, 3, 2),
    );

    await cloudRepository.enqueueJourney(journey.id);
    await localRepository.deleteJourney(journey.id);
    await cloudRepository.enqueueDelete(
      SyncEntityType.journey,
      journey.id,
    );

    final queued = await queueStore.nextBatch(limit: 25);
    expect(queued, hasLength(1));
    expect(queued.single.operation, SyncOperation.delete);

    final result = await cloudRepository.syncNow();
    expect(result.deleted, 1);
    expect(result.failures, 0);
    expect(provider.uploadedJourneys, isEmpty);
    expect(await cloudRepository.pendingCount(), 0);
  });

  test('queued Journey delete survives local row deletion', () async {
    final journey = await localRepository.createJourney(
      title: 'Delete me',
      destination: 'Padova',
      startDate: DateTime.utc(2026, 2, 1),
      endDate: DateTime.utc(2026, 2, 2),
    );

    await cloudRepository.enqueueJourney(journey.id);
    final pendingRow = await database.select(database.trips).getSingle();
    expect(pendingRow.syncStatus, 'PENDING_UPLOAD');

    final first = await cloudRepository.syncNow();
    expect(first.uploaded, 1);
    final uploadedCloudId = provider.uploadedJourneys.single.id;

    await localRepository.deleteJourney(journey.id);
    await cloudRepository.enqueueDelete(
      SyncEntityType.journey,
      journey.id,
    );

    final second = await cloudRepository.syncNow();

    expect(second.deleted, 1);
    expect(second.failures, 0);
    expect(provider.deletedJourneyIds, [uploadedCloudId]);
    expect(await cloudRepository.pendingCount(), 0);
  });
}

final class _RecordingCloudProvider implements CloudProvider {
  final List<CloudJourney> uploadedJourneys = [];
  final List<String> deletedJourneyIds = [];

  @override
  Future<bool> isAuthenticated() async => true;

  @override
  Future<CloudJourney> uploadJourney(CloudJourney payload) async {
    uploadedJourneys.add(payload);
    return payload;
  }

  @override
  Future<CloudMemory> uploadMemory(CloudMemory payload) async => payload;

  @override
  Future<CloudAlbumPhoto> uploadPhotoMetadata(
    CloudAlbumPhoto payload,
  ) async =>
      payload;

  @override
  Future<String> uploadPhotoFile(
    Uint8List bytes,
    String remotePath,
  ) async =>
      remotePath;

  @override
  Future<void> deleteJourney(String cloudId) async {
    deletedJourneyIds.add(cloudId);
  }

  @override
  Future<void> deleteMemory(String cloudId) async {}

  @override
  Future<void> deletePhoto(
    String cloudId,
    String? remoteFilePath,
  ) async {}

  @override
  Future<List<CloudJourney>> fetchJourneys(DateTime? updatedAfter) async =>
      const [];

  @override
  Future<List<CloudMemory>> fetchMemories(DateTime? updatedAfter) async =>
      const [];

  @override
  Future<List<CloudAlbumPhoto>> fetchPhotos(DateTime? updatedAfter) async =>
      const [];

  @override
  Future<Uint8List> downloadPhotoFile(String remotePath) async =>
      Uint8List(0);

  @override
  Future<void> uploadMemoryPhotoLinks(
    List<CloudMemoryPhotoLink> links,
  ) async {}

  @override
  Future<List<CloudMemoryPhotoLink>> fetchMemoryPhotoLinks() async =>
      const [];
}
