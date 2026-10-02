import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';
import 'package:wonderlog/core/ecosystem/life_bridge_v1.dart';
import 'package:wonderlog/features/journeys/application/journey_life_bridge_adapter.dart';
import 'package:wonderlog/features/journeys/domain/journey.dart';

void main() {
  Journey sampleJourney() => Journey(
        id: 'journey-42',
        title: 'Valle Aurina',
        destination: 'Campo Tures',
        country: 'Italia',
        startDate: DateTime.utc(2026, 8, 10),
        endDate: DateTime.utc(2026, 8, 14),
        description: 'Diario del viaggio.',
        latitude: 46.919,
        longitude: 11.955,
        favorite: true,
        archived: false,
        createdAt: DateTime.utc(2026, 8, 1),
        updatedAt: DateTime.utc(2026, 10, 2, 8, 30),
      );

  test('Wonderlog journey exports an Anna Life Bridge v1 COPY payload', () {
    final payload = JourneyLifeBridgeAdapter.payloadFor(
      sampleJourney(),
      exportedAt: DateTime.utc(2026, 10, 2, 9),
    );

    final json = jsonDecode(payload.encode()) as Map<String, dynamic>;
    final source = json['source'] as Map<String, dynamic>;
    final location = json['location'] as Map<String, dynamic>;
    final extensions = json['extensions'] as Map<String, dynamic>;
    final ecosystem = extensions['ecosystem'] as Map<String, dynamic>;

    expect(json['protocolVersion'], '1.0');
    expect(json['objectType'], 'journey');
    expect(json['transferMode'], 'copy');
    expect(json['bridgeId'], 'ecosystem:v1:wonderlog:journey:journey-42');
    expect(source['appId'], 'wonderlog');
    expect(source['objectId'], 'journey-42');
    expect(source['deepLink'], 'wonderlog://journey/journey-42');
    expect(
      source['idempotencyKey'],
      contains(':copy'),
    );
    expect(location['name'], 'Campo Tures');
    expect(location['latitude'], 46.919);
    expect(json['occurredAt'], '2026-08-10T00:00:00.000Z');
    expect(ecosystem['endAt'], '2026-08-14T00:00:00.000Z');
  });

  test('LINK and COPY keep bridgeId stable and idempotency distinct', () {
    final journey = sampleJourney();

    final copy = JourneyLifeBridgeAdapter.payloadFor(
      journey,
      transferMode: EcosystemTransferMode.copy,
    );
    final link = JourneyLifeBridgeAdapter.payloadFor(
      journey,
      transferMode: EcosystemTransferMode.link,
    );

    expect(copy.bridgeId, link.bridgeId);
    expect(link.transferMode, EcosystemTransferMode.link);
    expect(
      copy.bridgeId,
      'ecosystem:v1:wonderlog:journey:journey-42',
    );
    expect(
      copy.source['idempotencyKey'],
      isNot(link.source['idempotencyKey']),
    );
  });

  test('private envelopes cannot cross the Life Bridge boundary', () {
    final envelope = EcosystemEnvelope(
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'memory-1',
      createdAtUtc: DateTime.utc(2026, 10, 2),
      title: 'Private memory',
      privacyScope: EcosystemPrivacyScope.private,
    );

    expect(
      () => LifeBridgeV1Adapter.fromEnvelope(envelope),
      throwsStateError,
    );
  });

  test('media projection carries explicit handoff without local URI', () {
    final envelope = EcosystemEnvelope(
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'memory-2',
      createdAtUtc: DateTime.utc(2026, 10, 2),
      title: 'Memory',
      media: const [
        EcosystemMediaReference(
          id: 'photo-1',
          kind: 'photo',
          mimeType: 'image/jpeg',
          fileName: 'photo.jpg',
          handoff: EcosystemMediaHandoff(
            kind: EcosystemMediaHandoffKind.omitted,
            reason: 'explicit_binary_handoff_not_enabled_in_v1',
          ),
        ),
      ],
    );

    final encoded = LifeBridgeV1Adapter.fromEnvelope(envelope).encode();

    expect(encoded, isNot(contains('file://')));
    expect(encoded, isNot(contains('content://')));
    expect(encoded, contains('"transfer": "omitted"'));
    expect(encoded, contains('"handoff"'));
  });

  test('unsupported route objects fail closed for Anna v1', () {
    final envelope = EcosystemEnvelope(
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.route,
      sourceEntityId: 'route-1',
      createdAtUtc: DateTime.utc(2026, 10, 2),
      title: 'Route',
    );

    expect(
      () => LifeBridgeV1Adapter.fromEnvelope(envelope),
      throwsUnsupportedError,
    );
  });
}
