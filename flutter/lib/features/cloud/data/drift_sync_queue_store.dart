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
                row.entityType.equals(_entityTypeWire(item.entityType)) &
                row.localEntityId.equals(item.localEntityId) &
                row.operation.equals(_operationWire(item.operation)),
          ))
        .getSingleOrNull();

    final id = existing?.id ?? item.id;
    await database.into(database.cloudSyncQueue).insertOnConflictUpdate(
          db.CloudSyncQueueCompanion.insert(
            id: id,
            entityType: _entityTypeWire(item.entityType),
            localEntityId: item.localEntityId,
            operation: _operationWire(item.operation),
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
        entityType: _parseEntityType(row.entityType),
        localEntityId: row.localEntityId,
        operation: _parseOperation(row.operation),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.createdAt,
          isUtc: true,
        ),
        attemptCount: row.attemptCount,
        lastError: row.lastError,
      );

  String _entityTypeWire(SyncEntityType value) => switch (value) {
        SyncEntityType.journey => 'JOURNEY',
        SyncEntityType.memory => 'MEMORY',
        SyncEntityType.albumPhoto => 'ALBUM_PHOTO',
      };

  String _operationWire(SyncOperation value) => switch (value) {
        SyncOperation.createOrUpdate => 'CREATE_OR_UPDATE',
        SyncOperation.delete => 'DELETE',
      };

  SyncEntityType _parseEntityType(String value) => switch (value) {
        'JOURNEY' || 'journey' => SyncEntityType.journey,
        'MEMORY' || 'memory' => SyncEntityType.memory,
        'ALBUM_PHOTO' || 'albumPhoto' => SyncEntityType.albumPhoto,
        _ => throw FormatException('Unknown sync entity type: ' + value),
      };

  SyncOperation _parseOperation(String value) => switch (value) {
        'CREATE_OR_UPDATE' || 'createOrUpdate' =>
          SyncOperation.createOrUpdate,
        'DELETE' || 'delete' => SyncOperation.delete,
        _ => throw FormatException('Unknown sync operation: ' + value),
      };
}
