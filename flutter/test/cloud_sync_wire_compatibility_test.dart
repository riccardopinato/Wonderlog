import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/features/cloud/data/drift_sync_queue_store.dart';
import 'package:wonderlog/features/cloud/domain/cloud_models.dart';

void main() {
  test('new queue rows use Kotlin Room wire enum names', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftSyncQueueStore(database);

    await store.enqueue(
      SyncQueueItem(
        id: 'q',
        entityType: SyncEntityType.albumPhoto,
        localEntityId: 'p',
        operation: SyncOperation.createOrUpdate,
        createdAt: DateTime.utc(2026),
      ),
    );

    final row = await database.select(database.cloudSyncQueue).getSingle();
    expect(row.entityType, 'ALBUM_PHOTO');
    expect(row.operation, 'CREATE_OR_UPDATE');

    await database.close();
  });
}
