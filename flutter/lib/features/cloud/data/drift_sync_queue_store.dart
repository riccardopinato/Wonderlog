import 'package:drift/drift.dart';

import '../../../core/database/wonderlog_database.dart' as db;
import '../domain/cloud_models.dart';
import '../domain/sync_queue_store.dart';

final class DriftSyncQueueStore implements SyncQueueStore {
  DriftSyncQueueStore(this.database);

  final db.WonderlogDatabase database;

  @override
  Stream<int> watchPendingCount() {
    final count = database.cloudSyncQueue.id.count();
    final query = database.selectOnly(database.cloudSyncQueue)
      ..addColumns([count]);
    return query.watchSingle().map((row) => row.read(count) ?? 0);
  }

  @override
  Future<void> enqueue(SyncQueueItem item) async {
    final existing = await (database.select(database.cloudSyncQueue)
          ..where(
            (row) =>
                row.entityType.equals(item.entityType.name) &
                row.localEntityId.equals(item.localEntityId) &
                row.operation.equals(item.operation.name),
          ))
        .getSingleOrNull();

    final id = existing?.id ?? item.id;
    await database.into(database.cloudSyncQueue).insertOnConflictUpdate(
          db.CloudSyncQueueCompanion.insert(
            id: id,
            entityType: item.entityType.name,
            localEntityId: item.localEntityId,
            operation: item.operation.name,
            createdAt: item.createdAt.toUtc().millisecondsSinceEpoch,
            attemptCount: Value(item.attemptCount),
            lastError: Value(item.lastError),
          ),
        );
  }

  @override
  Future<List<SyncQueueItem>> nextBatch({
    required int limit,
  }) async {
    final safeLimit = limit.clamp(1, 500);
    final query = database.select(database.cloudSyncQueue)
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)])
      ..limit(safeLimit);
    final rows = await query.get();
    return rows.map(_toDomain).toList(growable: false);
  }

  @override
  Future<void> remove(String id) async {
    await (database.delete(database.cloudSyncQueue)
          ..where((row) => row.id.equals(id)))
        .go();
  }

  @override
  Future<void> markFailure({
    required String id,
    required String error,
  }) async {
    final row = await (database.select(database.cloudSyncQueue)
          ..where((item) => item.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return;
    await (database.update(database.cloudSyncQueue)
          ..where((item) => item.id.equals(id)))
        .write(
      db.CloudSyncQueueCompanion(
        attemptCount: Value(row.attemptCount + 1),
        lastError: Value(error),
      ),
    );
  }

  @override
  Future<void> clear() => database.delete(database.cloudSyncQueue).go();

  SyncQueueItem _toDomain(db.CloudSyncQueueData row) => SyncQueueItem(
        id: row.id,
        entityType: SyncEntityType.values.byName(row.entityType),
        localEntityId: row.localEntityId,
        operation: SyncOperation.values.byName(row.operation),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.createdAt,
          isUtc: true,
        ),
        attemptCount: row.attemptCount,
        lastError: row.lastError,
      );
}
