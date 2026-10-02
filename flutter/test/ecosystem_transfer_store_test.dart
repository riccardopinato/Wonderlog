import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/core/ecosystem/drift_ecosystem_transfer_store.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';

void main() {
  test('outbox deduplicates by target and idempotency key', () async {
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

    await store.enqueueOutbox(
      targetApp: EcosystemAppId.annasDiary,
      envelope: envelope,
    );
    await store.enqueueOutbox(
      targetApp: EcosystemAppId.annasDiary,
      envelope: envelope,
    );

    final pending = await store.watchPendingOutbox().first;
    expect(pending, hasLength(1));
    expect(pending.single.envelope.sourceEntityId, 'm1');

    await database.close();
  });

  test('inbox ignores duplicate deliveries', () async {
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

    await store.receiveInbox(envelope);
    await store.receiveInbox(envelope);

    final pending = await store.watchPendingInbox().first;
    expect(pending, hasLength(1));

    await database.close();
  });
}
