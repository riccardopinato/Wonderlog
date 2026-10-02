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
  Future<String> enqueueOutbox({
    required EcosystemAppId targetApp,
    required EcosystemEnvelope envelope,
  }) async {
    EcosystemContractValidator.ensureValid(envelope);

    final existing = await (database.select(database.ecosystemOutbox)
          ..where(
            (row) =>
                row.targetApp.equals(targetApp.wireValue) &
                row.idempotencyKey.equals(envelope.idempotencyKey),
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
        );
    return id;
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
                row.idempotencyKey.equals(envelope.idempotencyKey),
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
        );
  }

  @override
  Stream<List<EcosystemInboxItem>> watchPendingInbox() {
    final query = database.select(database.ecosystemInbox)
      ..where((row) => row.consumedAt.isNull())
      ..orderBy([(row) => OrderingTerm.asc(row.receivedAt)]);
    return query.watch().map(
          (rows) => rows.map(_inbox).toList(growable: false),
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
      ),
    );
  }

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
      );
}
