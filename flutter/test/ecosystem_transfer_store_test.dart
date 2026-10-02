import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/core/ecosystem/drift_ecosystem_transfer_store.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_codec.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';

void main() {
  test('outbox deduplicates by target and handoff idempotency key', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final envelope = EcosystemEnvelope(
      id: 'e1',
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'm1',
      createdAtUtc: DateTime.utc(2026),
      title: 'Memory',
    );

    await Future.wait([
      store.enqueueOutbox(
        targetApp: EcosystemAppId.annasDiary,
        envelope: envelope,
      ),
      store.enqueueOutbox(
        targetApp: EcosystemAppId.annasDiary,
        envelope: envelope,
      ),
    ]);

    final pending = await store.watchPendingOutbox().first;
    expect(pending, hasLength(1));
    expect(pending.single.envelope.sourceEntityId, 'm1');

    await database.close();
  });

  test('legacy COPY key deduplicates without suppressing a new LINK', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final envelope = EcosystemEnvelope(
      id: 'legacy-e1',
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'legacy-m1',
      createdAtUtc: DateTime.utc(2026),
      title: 'Legacy memory',
    );

    await database.into(database.ecosystemOutbox).insert(
          EcosystemOutboxCompanion.insert(
            id: 'legacy-row',
            targetApp: EcosystemAppId.annasDiary.wireValue,
            envelopeJson: EcosystemCodec.encode(envelope),
            idempotencyKey: envelope.idempotencyKey,
            createdAt: 1,
          ),
        );

    await store.enqueueOutbox(
      targetApp: EcosystemAppId.annasDiary,
      envelope: envelope,
    );
    expect(await store.watchPendingOutbox().first, hasLength(1));

    await store.enqueueOutbox(
      targetApp: EcosystemAppId.annasDiary,
      envelope: envelope.copyWith(
        transferMode: EcosystemTransferMode.link,
      ),
    );

    final pending = await store.watchPendingOutbox().first;
    expect(pending, hasLength(2));
    expect(
      pending.map((item) => item.envelope.transferMode).toSet(),
      {
        EcosystemTransferMode.copy,
        EcosystemTransferMode.link,
      },
    );

    await database.close();
  });

  test('inbox ignores concurrent duplicate deliveries', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final envelope = EcosystemEnvelope(
      id: 'e1',
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
