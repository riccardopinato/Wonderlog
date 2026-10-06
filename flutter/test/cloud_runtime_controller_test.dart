import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/features/cloud/application/cloud_runtime_controller.dart';
import 'package:wonderlog/features/cloud/data/cloud_restore_repository.dart';
import 'package:wonderlog/features/cloud/data/drift_cloud_local_data_source.dart';
import 'package:wonderlog/features/cloud/data/drift_sync_queue_store.dart';
import 'package:wonderlog/features/cloud/data/shared_preferences_cloud_backup_settings_repository.dart';
import 'package:wonderlog/features/cloud/domain/cloud_models.dart';
import 'package:wonderlog/features/cloud/domain/cloud_provider.dart';
import 'package:wonderlog/features/cloud/domain/cloud_sync_repository.dart';
import 'package:wonderlog/features/cloud/domain/restored_photo_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('cloud dataset binds only after entitled use and rejects account swap',
      () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final queue = DriftSyncQueueStore(database);
    final provider = _EmptyCloudProvider();
    final settings = SharedPreferencesCloudBackupSettingsRepository();
    var premium = false;
    var userId = 'user-a';

    final syncRepository = CloudSyncRepository(
      cloudProvider: provider,
      queueStore: queue,
      localDataSource: DriftCloudLocalDataSource(
        database: database,
        currentUserId: () => userId,
      ),
      assetReader: (_) async => null,
    );
    final restoreRepository = CloudRestoreRepository(
      database: database,
      cloudProvider: provider,
      photoStorage: _NoopRestoreStorage(),
    );
    final runtime = CloudRuntimeController(
      cloudProvider: provider,
      syncRepository: syncRepository,
      restoreRepository: restoreRepository,
      settingsRepository: settings,
      queueStore: queue,
      isPremium: () => premium,
      currentUserId: () => userId,
    );
    await runtime.initialize();

    expect(
      () => runtime.syncNow(),
      throwsA(
        isA<CloudRuntimeException>().having(
          (error) => error.reason,
          'reason',
          CloudRuntimeBlockReason.premiumRequired,
        ),
      ),
    );
    expect(await settings.getBoundCloudUserId(), isNull);

    premium = true;
    final summary = await runtime.syncNow();
    expect(summary.failures, 0);
    expect(await settings.getBoundCloudUserId(), 'user-a');

    userId = 'user-b';
    expect(
      () => runtime.syncNow(),
      throwsA(
        isA<CloudRuntimeException>().having(
          (error) => error.reason,
          'reason',
          CloudRuntimeBlockReason.accountMismatch,
        ),
      ),
    );

    runtime.dispose();
    await database.close();
  });
}

final class _NoopRestoreStorage implements RestoredPhotoStorage {
  @override
  Future<RestoredPhotoFiles> save({
    required String journeyId,
    required String photoId,
    required Uint8List bytes,
    String? fileName,
    String? mimeType,
  }) {
    throw StateError('No photo download expected in this test.');
  }
}

final class _EmptyCloudProvider implements CloudProvider {
  @override
  Future<bool> isAuthenticated() async => true;

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
  Future<void> deleteJourney(String cloudId) async {}

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
