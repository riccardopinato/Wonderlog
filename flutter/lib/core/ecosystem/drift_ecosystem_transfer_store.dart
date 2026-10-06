import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/wonderlog_database.dart' as db;
import 'ecosystem_codec.dart';
import 'ecosystem_contract_validator.dart';
import 'ecosystem_envelope.dart';
import 'ecosystem_models.dart';
import 'ecosystem_transfer_store.dart';

final class DriftEcosystemTransferStore implements EcosystemTransferStore {
  DriftEcosystemTransferStore(this.database);

  final db.WonderlogDatabase database;
  final Uuid _uuid = const Uuid();

  @override
  Stream<List<EcosystemOutboxItem>> watchPendingOutbox() {
    final query = database.select(database.ecosystemOutbox)
      ..where((row) => row.deliveredAt.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch().map(
          (rows) => rows.map(_outbox).toList(growable: false),
        );
  }

  @override
  Stream<List<EcosystemOutboxItem>> watchOutboxHistory() {
    final query = database.select(database.ecosystemOutbox)
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)]);
    return query.watch().map(
          (rows) => rows.map(_outbox).toList(growable: false),
        );
  }

  @override
  Future<String> enqueueOutbox({
    required EcosystemAppId targetApp,
    required EcosystemEnvelope envelope,
  }) async {
    EcosystemContractValidator.ensureValid(envelope);

    final existing = await (database.select(database.ecosystemOutbox)
          ..where(
            (row) =>
                row.targetApp.equals(targetApp.wireValue) &
                _idempotencyExpression(
                  row.idempotencyKey,
                  envelope,
                ),
          ))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final id = _uuid.v4();
    await database.into(database.ecosystemOutbox).insert(
          db.EcosystemOutboxCompanion.insert(
            id: id,
            targetApp: targetApp.wireValue,
            envelopeJson: EcosystemCodec.encode(envelope),
            idempotencyKey: envelope.idempotencyKey,
            createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );

    // Two concurrent callers may both miss the pre-insert lookup. The unique
    // key plus insertOrIgnore guarantees only one row wins; always read back
    // the canonical stored row so both callers receive the same durable id.
    final stored = await (database.select(database.ecosystemOutbox)
          ..where(
            (row) =>
                row.targetApp.equals(targetApp.wireValue) &
                row.idempotencyKey.equals(envelope.idempotencyKey),
          ))
        .getSingleOrNull();
    if (stored != null) return stored.id;

    // A pre-E1 v8 COPY row can still use the legacy key format. It cannot be
    // rewritten through a schema migration because both layouts are schema v8.
    final legacy = await (database.select(database.ecosystemOutbox)
          ..where(
            (row) =>
                row.targetApp.equals(targetApp.wireValue) &
                _idempotencyExpression(
                  row.idempotencyKey,
                  envelope,
                ),
          ))
        .getSingleOrNull();
    if (legacy != null) return legacy.id;

    throw StateError('Unable to persist ecosystem outbox item.');
  }

  @override
  Future<void> markOutboxDelivered(
    String id, {
    required DateTime deliveredAt,
  }) async {
    await (database.update(database.ecosystemOutbox)
          ..where((row) => row.id.equals(id)))
        .write(
      db.EcosystemOutboxCompanion(
        deliveredAt: Value(deliveredAt.toUtc().millisecondsSinceEpoch),
        lastError: const Value(null),
      ),
    );
  }

  @override
  Future<void> markOutboxFailure(
    String id, {
    required String error,
  }) async {
    final current = await (database.select(database.ecosystemOutbox)
          ..where((row) => row.id.equals(id)))
        .getSingleOrNull();
    if (current == null) return;

    await (database.update(database.ecosystemOutbox)
          ..where((row) => row.id.equals(id)))
        .write(
      db.EcosystemOutboxCompanion(
        attemptCount: Value(current.attemptCount + 1),
        lastError: Value(error),
      ),
    );
  }

  @override
  Future<void> receiveInbox(EcosystemEnvelope envelope) async {
    EcosystemContractValidator.ensureValid(envelope);
    final existing = await (database.select(database.ecosystemInbox)
          ..where(
            (row) =>
                row.sourceApp.equals(envelope.sourceApp.wireValue) &
                _idempotencyExpression(
                  row.idempotencyKey,
                  envelope,
                ),
          ))
        .getSingleOrNull();
    if (existing != null) return;

    await database.into(database.ecosystemInbox).insert(
          db.EcosystemInboxCompanion.insert(
            id: _uuid.v4(),
            sourceApp: envelope.sourceApp.wireValue,
            envelopeJson: EcosystemCodec.encode(envelope),
            idempotencyKey: envelope.idempotencyKey,
            receivedAt: DateTime.now().toUtc().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrIgnore,
        );
  }

  @override
  Stream<List<EcosystemInboxItem>> watchPendingInbox() {
    final query = database.select(database.ecosystemInbox)
      ..where(
        (row) =>
            row.consumedAt.isNull() &
            row.disposition.equals(EcosystemInboxDisposition.pending.name),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.receivedAt)]);
    return query.watch().map(
          (rows) => rows.map(_inbox).toList(growable: false),
        );
  }

  @override
  Stream<List<EcosystemInboxItem>> watchInboxHistory() {
    final query = database.select(database.ecosystemInbox)
      ..orderBy([(row) => OrderingTerm.desc(row.receivedAt)]);
    return query.watch().map(
          (rows) => rows.map(_inbox).toList(growable: false),
        );
  }

  @override
  Future<T?> runInboxMaterialization<T>(
    String id,
    Future<T> Function() materialize,
  ) =>
      database.transaction(() async {
        final claimed = await (database.update(database.ecosystemInbox)
              ..where(
                (row) =>
                    row.id.equals(id) &
                    row.consumedAt.isNull() &
                    row.disposition.equals(
                      EcosystemInboxDisposition.pending.name,
                    ),
              ))
            .write(
          db.EcosystemInboxCompanion(
            disposition: Value(EcosystemInboxDisposition.processing.name),
          ),
        );

        if (claimed != 1) return null;

        // All Wonderlog repositories participating in E2 use this same Drift
        // database. Any failure below rolls the claim and domain writes back,
        // returning the item to pending instead of leaving a half-import.
        return materialize();
      });

  @override
  Future<void> resolveInbox(
    String id, {
    required EcosystemInboxDisposition disposition,
    required DateTime resolvedAt,
    String? materializedJourneyId,
    String? materializedMemoryId,
  }) async {
    if (disposition == EcosystemInboxDisposition.pending ||
        disposition == EcosystemInboxDisposition.processing) {
      throw ArgumentError.value(disposition, 'disposition');
    }
    await (database.update(database.ecosystemInbox)
          ..where((row) => row.id.equals(id)))
        .write(
      db.EcosystemInboxCompanion(
        consumedAt: Value(resolvedAt.toUtc().millisecondsSinceEpoch),
        disposition: Value(disposition.name),
        materializedJourneyId: Value(materializedJourneyId),
        materializedMemoryId: Value(materializedMemoryId),
      ),
    );
  }

  @override
  Future<void> markInboxConsumed(
    String id, {
    required DateTime consumedAt,
  }) async {
    await (database.update(database.ecosystemInbox)
          ..where((row) => row.id.equals(id)))
        .write(
      db.EcosystemInboxCompanion(
        consumedAt: Value(consumedAt.toUtc().millisecondsSinceEpoch),
        disposition: const Value('seenLegacy'),
      ),
    );
  }

  Expression<bool> _idempotencyExpression(
    GeneratedColumn<String> column,
    EcosystemEnvelope envelope,
  ) {
    final current = column.equals(envelope.idempotencyKey);
    if (envelope.transferMode != EcosystemTransferMode.copy) {
      return current;
    }

    // Before Shared Ecosystem Core v1, schema-v8 rows had no transferMode.
    // Their semantics therefore map to COPY only. Recognize that historical
    // key without letting it suppress a LINK for the same source revision.
    return current | column.equals(_legacyV8IdempotencyKey(envelope));
  }

  String _legacyV8IdempotencyKey(EcosystemEnvelope envelope) =>
      '${envelope.sourceApp.wireValue}:'
      '${envelope.sourceEntityType.name}:'
      '${envelope.sourceEntityId}:'
      '${envelope.revision}';

  EcosystemOutboxItem _outbox(db.EcosystemOutboxData row) =>
      EcosystemOutboxItem(
        id: row.id,
        targetApp: EcosystemAppId.fromWire(row.targetApp),
        envelope: EcosystemCodec.decode(row.envelopeJson),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.createdAt,
          isUtc: true,
        ),
        deliveredAt: row.deliveredAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row.deliveredAt!,
                isUtc: true,
              ),
        attemptCount: row.attemptCount,
        lastError: row.lastError,
      );

  EcosystemInboxItem _inbox(db.EcosystemInboxData row) =>
      EcosystemInboxItem(
        id: row.id,
        sourceApp: EcosystemAppId.fromWire(row.sourceApp),
        envelope: EcosystemCodec.decode(row.envelopeJson),
        receivedAt: DateTime.fromMillisecondsSinceEpoch(
          row.receivedAt,
          isUtc: true,
        ),
        consumedAt: row.consumedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row.consumedAt!,
                isUtc: true,
              ),
        disposition: EcosystemInboxDisposition.fromWire(
          row.disposition,
          consumed: row.consumedAt != null,
        ),
        materializedJourneyId: row.materializedJourneyId,
        materializedMemoryId: row.materializedMemoryId,
      );
}
