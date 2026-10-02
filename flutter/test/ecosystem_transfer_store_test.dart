import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/core/ecosystem/drift_ecosystem_transfer_store.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_codec.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';

void main() {
  test('outbox deduplicates same target, revision and transfer mode', () async {
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

    final first = await store.enqueueOutbox(
      targetApp: EcosystemAppId.annasDiary,
      envelope: envelope,
    );
    final second = await store.enqueueOutbox(
      targetApp: EcosystemAppId.annasDiary,
      envelope: envelope,
    );

    expect(first, second);
    final pending = await store.watchPendingOutbox().first;
    expect(pending, hasLength(1));
    expect(pending.single.envelope.sourceEntityId, 'm1');

    await database.close();
  });

  test('legacy pre-E1 COPY key deduplicates after upgrade', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final envelope = EcosystemEnvelope(
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'm1',
      createdAtUtc: DateTime.utc(2026),
      title: 'Memory',
      revision: 3,
      transferMode: EcosystemTransferMode.copy,
    );

    await database.into(database.ecosystemOutbox).insert(
          EcosystemOutboxCompanion.insert(
            id: 'legacy-row',
            targetApp: EcosystemAppId.annasDiary.wireValue,
            envelopeJson: EcosystemCodec.encode(envelope),
            idempotencyKey: 'wonderlog:memory:m1:3',
            createdAt: DateTime.utc(2026).millisecondsSinceEpoch,
          ),
        );

    final id = await store.enqueueOutbox(
      targetApp: EcosystemAppId.annasDiary,
      envelope: envelope,
    );

    expect(id, 'legacy-row');
    expect(await store.watchPendingOutbox().first, hasLength(1));
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

  test('inbox ignores duplicate deliveries', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final envelope = EcosystemEnvelope(
      sourceApp: EcosystemAppId.annasDiary,
      sourceEntityType: EcosystemEntityType.note,
      sourceEntityId: 'n1',
      createdAtUtc: DateTime.utc(2026),
      text: 'Shared thought',
    );

    await store.receiveInbox(envelope);
    await store.receiveInbox(envelope);

    final pending = await store.watchPendingInbox().first;
    expect(pending, hasLength(1));

    await database.close();
  });
}
