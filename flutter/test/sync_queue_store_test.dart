import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/features/cloud/data/drift_sync_queue_store.dart';
import 'package:wonderlog/features/cloud/domain/cloud_models.dart';

void main() {
  late WonderlogDatabase database;
  late DriftSyncQueueStore store;

  setUp(() {
    database = WonderlogDatabase(NativeDatabase.memory());
    store = DriftSyncQueueStore(database);
  });

  tearDown(() => database.close());

  test('queue deduplicates entity operation and keeps oldest id', () async {
    await store.enqueue(
      SyncQueueItem(
        id: 'q1',
        entityType: SyncEntityType.memory,
        localEntityId: 'm1',
        operation: SyncOperation.createOrUpdate,
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
    await store.enqueue(
      SyncQueueItem(
        id: 'q2',
        entityType: SyncEntityType.memory,
        localEntityId: 'm1',
        operation: SyncOperation.createOrUpdate,
        createdAt: DateTime.utc(2026, 1, 2),
      ),
    );

    final batch = await store.nextBatch(limit: 25);
    expect(batch, hasLength(1));
    expect(batch.single.id, 'q1');
  });

  test('markFailure increments retry count', () async {
    await store.enqueue(
      SyncQueueItem(
        id: 'q1',
        entityType: SyncEntityType.journey,
        localEntityId: 'j1',
        operation: SyncOperation.createOrUpdate,
        createdAt: DateTime.utc(2026),
      ),
    );

    await store.markFailure(id: 'q1', error: 'offline');
    final item = (await store.nextBatch(limit: 25)).single;
    expect(item.attemptCount, 1);
    expect(item.lastError, 'offline');
  });
}
