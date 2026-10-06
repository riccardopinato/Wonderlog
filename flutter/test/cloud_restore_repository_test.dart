import 'package:drift/drift.dart';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/features/cloud/data/cloud_restore_repository.dart';
import 'package:wonderlog/features/cloud/domain/cloud_models.dart';
import 'package:wonderlog/features/cloud/domain/cloud_provider.dart';
import 'package:wonderlog/features/cloud/domain/restored_photo_storage.dart';
import 'package:wonderlog/features/memories/data/drift_wonderlog_repository.dart';

void main() {
  test('restore rebuilds Journey, Memory, Photo and relationship', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final provider = _FakeProvider();
    final storage = _FakeStorage();
    final repository = CloudRestoreRepository(
      database: database,
      cloudProvider: provider,
      photoStorage: storage,
    );

    final summary = await repository.restoreEverything();

    expect(summary.journeysInserted, 1);
    expect(summary.memoriesInserted, 1);
    expect(summary.photosInserted, 1);
    expect(summary.memoryPhotoLinksRestored, 1);
    expect(summary.photoFilesDownloaded, 1);
    expect(await database.select(database.trips).get(), hasLength(1));
    expect(await database.select(database.memories).get(), hasLength(1));
    expect(await database.select(database.albumPhotos).get(), hasLength(1));
    expect(await database.select(database.memoryPhotos).get(), hasLength(1));

    await database.close();
  });

  test('restore flags newer cloud data when local edit is unsynced', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final localRepository = DriftWonderlogRepository(database);
    final journey = await localRepository.createJourney(
      title: 'Local title',
      destination: 'Padova',
      startDate: DateTime.utc(2026, 8, 10),
      endDate: DateTime.utc(2026, 8, 11),
    );

    final repository = CloudRestoreRepository(
      database: database,
      cloudProvider: _ConflictProvider(journey.id),
      photoStorage: _FakeStorage(),
    );

    final summary = await repository.restoreEverything();
    final restored = await localRepository.watchJourney(journey.id).first;

    expect(summary.conflicts, 1);
    expect(summary.journeysUpdated, 0);
    expect(restored?.title, 'Local title');

    final row = await (database.select(database.trips)
          ..where((item) => item.id.equals(journey.id)))
        .getSingle();
    expect(row.syncStatus, 'CONFLICT');

    await database.close();
  });
}

final class _FakeStorage implements RestoredPhotoStorage {
  @override
  Future<RestoredPhotoFiles> save({
    required String journeyId,
    required String photoId,
    required Uint8List bytes,
    String? fileName,
    String? mimeType,
  }) async =>
      RestoredPhotoFiles(
        originalPath: '/tmp/' + photoId + '.jpg',
        thumbnailPath: '/tmp/' + photoId + '.jpg',
        fileSize: bytes.length,
        width: 0,
        height: 0,
      );
}

class _FakeProvider implements CloudProvider {
  @override
  Future<bool> isAuthenticated() async => true;

  @override
  Future<List<CloudJourney>> fetchJourneys(DateTime? updatedAfter) async => [
        CloudJourney(
          id: 'cj',
          ownerId: 'u',
          localReferenceId: 'j',
          title: 'Trip',
          destination: 'Place',
          country: 'IT',
          description: '',
          startDate: '2026-08-10',
          endDate: '2026-08-14',
          accentTheme: 'Preset_0',
          coverPhotoCloudId: null,
          createdAt: DateTime.utc(2026, 8, 10),
          updatedAt: DateTime.utc(2026, 8, 10),
        ),
      ];

  @override
  Future<List<CloudMemory>> fetchMemories(DateTime? updatedAfter) async => [
        CloudMemory(
          id: 'cm',
          ownerId: 'u',
          journeyCloudId: 'cj',
          localReferenceId: 'm',
          title: 'Memory',
          journalText: 'Text',
          date: '2026-08-10',
          locationName: 'Place',
          latitude: 46,
          longitude: 11,
          mood: 'HAPPY',
          tags: const ['trip'],
          createdAt: DateTime.utc(2026, 8, 10),
          updatedAt: DateTime.utc(2026, 8, 10),
        ),
      ];

  @override
  Future<List<CloudAlbumPhoto>> fetchPhotos(DateTime? updatedAfter) async => [
        CloudAlbumPhoto(
          id: 'cp',
          ownerId: 'u',
          journeyCloudId: 'cj',
          localReferenceId: 'p',
          remoteFilePath: 'u/journeys/j/photos/p.jpg',
          fileName: 'p.jpg',
          mimeType: 'image/jpeg',
          capturedAt: DateTime.utc(2026, 8, 10),
          latitude: 46,
          longitude: 11,
          locationName: 'Place',
          displayOrder: 0,
          isCoverPhoto: true,
          createdAt: DateTime.utc(2026, 8, 10),
          updatedAt: DateTime.utc(2026, 8, 10),
        ),
      ];

  @override
  Future<List<CloudMemoryPhotoLink>> fetchMemoryPhotoLinks() async => const [
        CloudMemoryPhotoLink(
          ownerId: 'u',
          memoryCloudId: 'cm',
          photoCloudId: 'cp',
          displayOrder: 0,
          isHeroPhoto: true,
        ),
      ];

  @override
  Future<Uint8List> downloadPhotoFile(String remotePath) async =>
      Uint8List.fromList([1, 2, 3]);

  @override
  Future<void> deleteJourney(String cloudId) async {}

  @override
  Future<void> deleteMemory(String cloudId) async {}

  @override
  Future<void> deletePhoto(String cloudId, String? remoteFilePath) async {}

  @override
  Future<CloudJourney> uploadJourney(CloudJourney payload) async => payload;

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
  Future<void> uploadMemoryPhotoLinks(
    List<CloudMemoryPhotoLink> links,
  ) async {}
}


final class _ConflictProvider extends _FakeProvider {
  _ConflictProvider(this.localReferenceId);

  final String localReferenceId;

  @override
  Future<List<CloudJourney>> fetchJourneys(DateTime? updatedAfter) async => [
        CloudJourney(
          id: 'cj-conflict',
          ownerId: 'u',
          localReferenceId: localReferenceId,
          title: 'Cloud title',
          destination: 'Padova',
          country: 'IT',
          description: '',
          startDate: '2026-08-10',
          endDate: '2026-08-11',
          accentTheme: 'Preset_0',
          coverPhotoCloudId: null,
          createdAt: DateTime.utc(2026, 8, 10),
          updatedAt: DateTime.utc(2030, 1, 1),
        ),
      ];

  @override
  Future<List<CloudMemory>> fetchMemories(DateTime? updatedAfter) async =>
      const [];

  @override
  Future<List<CloudAlbumPhoto>> fetchPhotos(DateTime? updatedAfter) async =>
      const [];

  @override
  Future<List<CloudMemoryPhotoLink>> fetchMemoryPhotoLinks() async =>
      const [];
}
