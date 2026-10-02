import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/core/ecosystem/drift_ecosystem_transfer_store.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_local_transport.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_registry.dart';

void main() {
  late WonderlogDatabase database;
  late DriftEcosystemTransferStore store;
  late EcosystemRegistry registry;

  setUp(() {
    database = WonderlogDatabase(NativeDatabase.memory());
    store = DriftEcosystemTransferStore(database);
    registry = EcosystemRegistry(
      const [
        EcosystemAppRegistration(
          appId: EcosystemAppId.wonderlog,
          acceptedEntityTypes: {
            EcosystemEntityType.journey,
            EcosystemEntityType.memory,
          },
          transferModes: {
            EcosystemTransferMode.copy,
            EcosystemTransferMode.link,
          },
          capabilities: {
            EcosystemCapability.copy,
            EcosystemCapability.link,
            EcosystemCapability.places,
            EcosystemCapability.people,
            EcosystemCapability.mediaMetadata,
            EcosystemCapability.sourceDeepLink,
            EcosystemCapability.fallbackText,
          },
          importScheme: 'wonderlog',
        ),
        EcosystemAppRegistration(
          appId: EcosystemAppId.annasDiary,
          acceptedEntityTypes: {
            EcosystemEntityType.journey,
            EcosystemEntityType.memory,
          },
          transferModes: {
            EcosystemTransferMode.copy,
            EcosystemTransferMode.link,
          },
          capabilities: {
            EcosystemCapability.copy,
            EcosystemCapability.link,
            EcosystemCapability.places,
            EcosystemCapability.people,
            EcosystemCapability.mediaMetadata,
            EcosystemCapability.sourceDeepLink,
            EcosystemCapability.fallbackText,
          },
          importScheme: 'annasdiary',
        ),
      ],
    );
  });

  tearDown(() => database.close());

  EcosystemEnvelope sampleEnvelope({
    EcosystemPrivacyScope privacyScope =
        EcosystemPrivacyScope.explicitShare,
  }) =>
      EcosystemEnvelope(
        id: 'wonderlog-memory-42',
        sourceApp: EcosystemAppId.wonderlog,
        sourceEntityType: EcosystemEntityType.memory,
        sourceEntityId: 'memory-42',
        createdAtUtc: DateTime.utc(2026, 8, 14, 18, 45),
        title: 'Cascate di Riva',
        text: 'Giornata alle cascate',
        places: const [
          EcosystemPlace(
            name: 'Cascate di Riva',
            latitude: 46.929,
            longitude: 11.956,
          ),
        ],
        media: const [
          EcosystemMediaReference(
            kind: 'photo',
            localReference: 'file:///private/wonderlog/photo.jpg',
            mimeType: 'image/jpeg',
            fileName: 'photo.jpg',
          ),
        ],
        sourceDeepLink: 'wonderlog://memory/memory-42',
        privacyScope: privacyScope,
        revision: 7,
      );

  test('COPY and LINK remain distinct over one canonical bridge identity',
      () async {
    final transport = EcosystemLocalTransport(
      localApp: EcosystemAppId.wonderlog,
      registry: registry,
      store: store,
    );

    final copy = await transport.prepare(
      targetApp: EcosystemAppId.annasDiary,
      envelope: sampleEnvelope(),
      transferMode: EcosystemTransferMode.copy,
      createdAtUtc: DateTime.utc(2026, 10, 2, 14),
    );
    final link = await transport.prepare(
      targetApp: EcosystemAppId.annasDiary,
      envelope: sampleEnvelope(),
      transferMode: EcosystemTransferMode.link,
      createdAtUtc: DateTime.utc(2026, 10, 2, 14, 1),
    );

    expect(copy.packet.envelope.transferMode, EcosystemTransferMode.copy);
    expect(link.packet.envelope.transferMode, EcosystemTransferMode.link);
    expect(copy.packet.envelope.bridgeId, link.packet.envelope.bridgeId);
    expect(copy.destinationUri?.scheme, 'annasdiary');
    expect(copy.fallbackPayload, isNotEmpty);
    expect(copy.fallbackText, contains('Cascate di Riva'));

    final pending = await store.watchPendingOutbox().first;
    expect(pending, hasLength(2));
    expect(
      pending.map((item) => item.envelope.transferMode).toSet(),
      {
        EcosystemTransferMode.copy,
        EcosystemTransferMode.link,
      },
    );
  });

  test('encoded handoff round-trips into a persistent inbox', () async {
    final sender = EcosystemLocalTransport(
      localApp: EcosystemAppId.wonderlog,
      registry: registry,
      store: store,
    );
    final receiver = EcosystemLocalTransport(
      localApp: EcosystemAppId.annasDiary,
      registry: registry,
      store: store,
    );

    final plan = await sender.prepare(
      targetApp: EcosystemAppId.annasDiary,
      envelope: sampleEnvelope(),
      transferMode: EcosystemTransferMode.copy,
    );

    await receiver.receiveEncoded(plan.fallbackPayload);
    await receiver.receiveEncoded(plan.fallbackPayload);

    final inbox = await store.watchPendingInbox().first;
    expect(inbox, hasLength(1));
    expect(inbox.single.envelope.sourceEntityId, 'memory-42');
    expect(
      inbox.single.envelope.effectiveProvenance.canonicalApp,
      EcosystemAppId.wonderlog,
    );
  });

  test('deep-link handoff never leaks local media references', () async {
    final sender = EcosystemLocalTransport(
      localApp: EcosystemAppId.wonderlog,
      registry: registry,
      store: store,
    );
    final receiver = EcosystemLocalTransport(
      localApp: EcosystemAppId.annasDiary,
      registry: registry,
      store: store,
    );

    final plan = await sender.prepare(
      targetApp: EcosystemAppId.annasDiary,
      envelope: sampleEnvelope(),
      transferMode: EcosystemTransferMode.copy,
    );

    expect(
      plan.fallbackPayload,
      isNot(contains('file:///private/wonderlog/photo.jpg')),
    );
    await receiver.receiveUri(plan.destinationUri!);

    final inbox = await store.watchPendingInbox().first;
    expect(inbox.single.envelope.media.single.localReference, isNull);
    expect(inbox.single.envelope.media.single.fileName, 'photo.jpg');
  });

  test('incoming packet cannot under-declare required capabilities', () async {
    final limitedRegistry = EcosystemRegistry(
      const [
        EcosystemAppRegistration(
          appId: EcosystemAppId.annasDiary,
          acceptedEntityTypes: {
            EcosystemEntityType.memory,
          },
          transferModes: {
            EcosystemTransferMode.copy,
          },
          capabilities: {
            EcosystemCapability.copy,
            EcosystemCapability.places,
            EcosystemCapability.sourceDeepLink,
            EcosystemCapability.fallbackText,
          },
          importScheme: 'annasdiary',
        ),
      ],
    );
    final receiver = EcosystemLocalTransport(
      localApp: EcosystemAppId.annasDiary,
      registry: limitedRegistry,
      store: store,
    );
    final packet = EcosystemHandoffPacket(
      targetApp: EcosystemAppId.annasDiary,
      envelope: sampleEnvelope(),
      createdAtUtc: DateTime.utc(2026, 10, 2),
    );

    await expectLater(
      receiver.receiveEncoded(packet.encode()),
      throwsA(isA<EcosystemTransportException>()),
    );
    expect(await store.watchPendingInbox().first, isEmpty);
  });

  test('private envelopes fail closed before entering the outbox', () async {
    final transport = EcosystemLocalTransport(
      localApp: EcosystemAppId.wonderlog,
      registry: registry,
      store: store,
    );

    await expectLater(
      transport.prepare(
        targetApp: EcosystemAppId.annasDiary,
        envelope: sampleEnvelope(
          privacyScope: EcosystemPrivacyScope.private,
        ),
        transferMode: EcosystemTransferMode.copy,
      ),
      throwsA(isA<EcosystemTransportException>()),
    );
  });

  test('packets addressed to another app fail closed', () async {
    final sender = EcosystemLocalTransport(
      localApp: EcosystemAppId.wonderlog,
      registry: registry,
      store: store,
    );
    final wrongReceiver = EcosystemLocalTransport(
      localApp: EcosystemAppId.wonderlog,
      registry: registry,
      store: store,
    );

    final plan = await sender.prepare(
      targetApp: EcosystemAppId.annasDiary,
      envelope: sampleEnvelope(),
      transferMode: EcosystemTransferMode.copy,
    );

    await expectLater(
      wrongReceiver.receiveEncoded(plan.fallbackPayload),
      throwsA(isA<EcosystemTransportException>()),
    );
  });

  test('malformed packet fields fail as FormatException', () {
    final malformed = jsonEncode({
      'protocolVersion': ecosystemLocalHandoffProtocolVersion,
      'targetApp': 'unknown_app',
      'createdAtUtc': 'not-a-date',
      'envelope': sampleEnvelope().toJson(),
    });

    expect(
      () => EcosystemHandoffPacket.decode(malformed),
      throwsFormatException,
    );
  });

  test('future handoff protocol versions fail closed', () async {
    final sender = EcosystemLocalTransport(
      localApp: EcosystemAppId.wonderlog,
      registry: registry,
      store: store,
    );
    final plan = await sender.prepare(
      targetApp: EcosystemAppId.annasDiary,
      envelope: sampleEnvelope(),
      transferMode: EcosystemTransferMode.copy,
    );
    final json = jsonDecode(plan.fallbackPayload) as Map<String, dynamic>;
    json['protocolVersion'] = '99.0';

    expect(
      () => EcosystemHandoffPacket.decode(jsonEncode(json)),
      throwsFormatException,
    );
  });
}
