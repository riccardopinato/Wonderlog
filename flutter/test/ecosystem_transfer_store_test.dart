import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/core/ecosystem/drift_ecosystem_transfer_store.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_codec.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_transfer_store.dart';

void main() {
  test('outbox deduplicates concurrent same-mode delivery atomically',
      () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final envelope = EcosystemEnvelope(
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'm1',
      createdAtUtc: DateTime.utc(2026),
      title: 'Memory',
      revision: 3,
    );

    final ids = await Future.wait([
      store.enqueueOutbox(
        targetApp: EcosystemAppId.annasDiary,
        envelope: envelope,
      ),
      store.enqueueOutbox(
        targetApp: EcosystemAppId.annasDiary,
        envelope: envelope,
      ),
    ]);

    expect(ids.toSet(), hasLength(1));
    final pending = await store.watchPendingOutbox().first;
    expect(pending, hasLength(1));
    expect(pending.single.id, ids.toSet().single);
    expect(pending.single.envelope.sourceEntityId, 'm1');

    await database.close();
  });

  test('legacy v8 COPY key deduplicates without suppressing LINK', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final copy = EcosystemEnvelope(
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'legacy-m1',
      createdAtUtc: DateTime.utc(2026),
      title: 'Legacy memory',
      revision: 5,
    );
    final legacyKey =
        'wonderlog:memory:legacy-m1:5';

    await database.into(database.ecosystemOutbox).insert(
          EcosystemOutboxCompanion.insert(
            id: 'legacy-row',
            targetApp: EcosystemAppId.annasDiary.wireValue,
            envelopeJson: EcosystemCodec.encode(copy),
            idempotencyKey: legacyKey,
            createdAt: 1,
          ),
        );

    final copyId = await store.enqueueOutbox(
      targetApp: EcosystemAppId.annasDiary,
      envelope: copy,
    );
    expect(copyId, 'legacy-row');
    expect(await store.watchPendingOutbox().first, hasLength(1));

    final link = EcosystemEnvelope(
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'legacy-m1',
      createdAtUtc: DateTime.utc(2026),
      title: 'Legacy memory',
      sourceDeepLink: 'wonderlog://memory/legacy-m1',
      transferMode: EcosystemTransferMode.link,
      revision: 5,
    );
    final linkId = await store.enqueueOutbox(
      targetApp: EcosystemAppId.annasDiary,
      envelope: link,
    );

    expect(linkId, isNot(copyId));
    expect(await store.watchPendingOutbox().first, hasLength(2));
    await database.close();
  });

  test('COPY and LINK are distinct durable deliveries', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);

    EcosystemEnvelope build(EcosystemTransferMode mode) => EcosystemEnvelope(
          sourceApp: EcosystemAppId.wonderlog,
          sourceEntityType: EcosystemEntityType.journey,
          sourceEntityId: 'j1',
          createdAtUtc: DateTime.utc(2026),
          title: 'Trip',
          sourceDeepLink: 'wonderlog://journey/j1',
          revision: 4,
          transferMode: mode,
        );

    await store.enqueueOutbox(
      targetApp: EcosystemAppId.annasDiary,
      envelope: build(EcosystemTransferMode.copy),
    );
    await store.enqueueOutbox(
      targetApp: EcosystemAppId.annasDiary,
      envelope: build(EcosystemTransferMode.link),
    );

    expect(await store.watchPendingOutbox().first, hasLength(2));
    await database.close();
  });

  test('inbox ignores concurrent duplicate deliveries', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final envelope = EcosystemEnvelope(
      sourceApp: EcosystemAppId.annasDiary,
      sourceEntityType: EcosystemEntityType.note,
      sourceEntityId: 'n1',
      createdAtUtc: DateTime.utc(2026),
      text: 'Shared thought',
    );

    await Future.wait([
      store.receiveInbox(envelope),
      store.receiveInbox(envelope),
    ]);

    final pending = await store.watchPendingInbox().first;
    expect(pending, hasLength(1));

    await database.close();
  });

  test('resolved inbox item remains available in durable history', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final envelope = EcosystemEnvelope(
      sourceApp: EcosystemAppId.annasDiary,
      sourceEntityType: EcosystemEntityType.note,
      sourceEntityId: 'history-1',
      createdAtUtc: DateTime.utc(2026, 10, 5),
      title: 'History item',
    );

    await store.receiveInbox(envelope);
    final item = (await store.watchPendingInbox().first).single;
    final result = await store.runInboxMaterialization(
      item.id,
      () async {
        await store.resolveInbox(
          item.id,
          disposition: EcosystemInboxDisposition.savedFreeMemory,
          resolvedAt: DateTime.utc(2026, 10, 5, 16),
          materializedMemoryId: 'memory-1',
        );
        return 'resolved';
      },
    );
    expect(result, 'resolved');

    expect(await store.watchPendingInbox().first, isEmpty);
    final history = await store.watchInboxHistory().first;
    expect(history, hasLength(1));
    expect(
      history.single.disposition,
      EcosystemInboxDisposition.savedFreeMemory,
    );
    expect(history.single.materializedMemoryId, 'memory-1');
    expect(history.single.isPending, isFalse);

    await database.close();
  });

  test('failed claimed materialization rolls back to pending', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final envelope = EcosystemEnvelope(
      sourceApp: EcosystemAppId.annasDiary,
      sourceEntityType: EcosystemEntityType.note,
      sourceEntityId: 'rollback-1',
      createdAtUtc: DateTime.utc(2026, 10, 6),
      title: 'Rollback',
    );
    await store.receiveInbox(envelope);
    final item = (await store.watchPendingInbox().first).single;

    expect(
      () => store.runInboxMaterialization<void>(
        item.id,
        () async {
          throw StateError('boom');
        },
      ),
      throwsStateError,
    );

    final pending = await store.watchPendingInbox().first;
    expect(pending, hasLength(1));
    expect(pending.single.id, item.id);
    expect(pending.single.disposition, EcosystemInboxDisposition.pending);

    await database.close();
  });

}
