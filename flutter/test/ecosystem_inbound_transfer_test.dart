import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/core/ecosystem/drift_ecosystem_transfer_store.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_inbound_transfer_service.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_local_transport.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';

void main() {
  EcosystemTransferPackage annaNotePackage() => EcosystemTransferPackage(
        targetApp: EcosystemAppId.wonderlog,
        createdAtUtc: DateTime.utc(2026, 10, 2, 12),
        envelope: EcosystemEnvelope(
          sourceApp: EcosystemAppId.annasDiary,
          sourceEntityType: EcosystemEntityType.note,
          sourceEntityId: 'moment-42',
          createdAtUtc: DateTime.utc(2026, 10, 1, 18),
          title: 'Una sera insieme',
          text: 'Momento condiviso esplicitamente con Wonderlog.',
          sourceDeepLink: 'annasdiary://moment/moment-42',
          transferMode: EcosystemTransferMode.copy,
          revision: 7,
          provenance: const EcosystemProvenance(
            ownerApp: EcosystemAppId.annasDiary,
            ownerEntityType: EcosystemEntityType.note,
            ownerEntityId: 'moment-42',
            ownerRevision: 7,
            canonicalDeepLink: 'annasdiary://moment/moment-42',
          ),
          fallback: const EcosystemFallback(
            plainText:
                'Una sera insieme\n\nMomento condiviso esplicitamente con Wonderlog.',
            sourceDeepLink: 'annasdiary://moment/moment-42',
          ),
        ),
      );

  test('Anna -> Wonderlog portable package lands in inbox once', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final service = EcosystemInboundTransferService(store: store);

    final encoded =
        EcosystemLocalTransportCodec.encode(annaNotePackage());

    final first = await service.acceptEncoded(encoded);
    final second = await service.acceptEncoded(encoded);

    expect(first.status, EcosystemInboundStatus.accepted);
    expect(second.status, EcosystemInboundStatus.accepted);

    final inbox = await store.watchPendingInbox().first;
    expect(inbox, hasLength(1));
    expect(inbox.single.sourceApp, EcosystemAppId.annasDiary);
    expect(inbox.single.envelope.provenance.ownerApp,
        EcosystemAppId.annasDiary);
    expect(inbox.single.envelope.bridgeId,
        'ecosystem:v1:annas_diary:note:moment-42');

    await database.close();
  });

  test('package for another app is rejected before inbox persistence',
      () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final service = EcosystemInboundTransferService(store: store);

    final wrongTarget = EcosystemTransferPackage(
      targetApp: EcosystemAppId.notes,
      createdAtUtc: DateTime.utc(2026, 10, 2),
      envelope: annaNotePackage().envelope,
    );

    final result = await service.acceptPackage(wrongTarget);
    expect(result.status, EcosystemInboundStatus.wrongTarget);
    expect(await store.watchPendingInbox().first, isEmpty);

    await database.close();
  });

  test('clipboard fallback is accepted through the same contract', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final store = DriftEcosystemTransferStore(database);
    final service = EcosystemInboundTransferService(store: store);

    final clipboard =
        EcosystemLocalTransportCodec.clipboardText(annaNotePackage());
    final result = await service.acceptClipboardText(clipboard);

    expect(result.status, EcosystemInboundStatus.accepted);
    expect(await store.watchPendingInbox().first, hasLength(1));

    await database.close();
  });
}
