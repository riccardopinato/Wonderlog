import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/core/ecosystem/drift_ecosystem_transfer_store.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_codec.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';

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
    expect(pending.single.id, ids.single);
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
}
