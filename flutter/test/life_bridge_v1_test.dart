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
    final wonderlog = extensions['wonderlog'] as Map<String, dynamic>;

    expect(json['protocolVersion'], '1.0');
    expect(json['objectType'], 'journey');
    expect(json['transferMode'], 'copy');
    expect(source['appId'], 'wonderlog');
    expect(source['objectId'], 'journey-42');
    expect(source['deepLink'], 'wonderlog://journey/journey-42');
    expect(location['name'], 'Campo Tures');
    expect(location['latitude'], 46.919);
    expect(json['occurredAt'], '2026-08-10T00:00:00.000Z');
    expect(wonderlog['endAt'], '2026-08-14T00:00:00.000Z');
  });

  test('LINK and COPY keep a stable bridgeId for the same source revision', () {
    final journey = sampleJourney();

    final copy = JourneyLifeBridgeAdapter.payloadFor(
      journey,
      transferMode: LifeBridgeTransferMode.copy,
    );
    final link = JourneyLifeBridgeAdapter.payloadFor(
      journey,
      transferMode: LifeBridgeTransferMode.link,
    );

    expect(copy.bridgeId, link.bridgeId);
    expect(link.transferMode, LifeBridgeTransferMode.link);
    expect(
      copy.bridgeId,
      'life-bridge:v1:wonderlog:journey:journey-42:'
      '${journey.updatedAt.toUtc().millisecondsSinceEpoch}',
    );
  });

  test('private envelopes cannot cross the Life Bridge boundary', () {
    final envelope = EcosystemEnvelope(
      id: 'private-1',
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'memory-1',
      createdAtUtc: DateTime.utc(2026, 10, 2),
      privacyScope: EcosystemPrivacyScope.private,
    );

    expect(
      () => LifeBridgeV1Adapter.fromEnvelope(
        envelope,
        transferMode: LifeBridgeTransferMode.copy,
      ),
      throwsStateError,
    );
  });

  test('local media references never leak into Anna payloads', () {
    final envelope = EcosystemEnvelope(
      id: 'memory-2',
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'memory-2',
      createdAtUtc: DateTime.utc(2026, 10, 2),
      media: const [
        EcosystemMediaReference(
          kind: 'photo',
          localReference: 'file:///private/wonderlog/photo.jpg',
          mimeType: 'image/jpeg',
          fileName: 'photo.jpg',
        ),
      ],
    );

    final encoded = LifeBridgeV1Adapter.fromEnvelope(
      envelope,
      transferMode: LifeBridgeTransferMode.copy,
    ).encode();

    expect(encoded, isNot(contains('file:///private/wonderlog/photo.jpg')));
    expect(encoded, contains('"transfer": "omitted"'));
  });

  test('unsupported route objects fail closed for Anna v1', () {
    final envelope = EcosystemEnvelope(
      id: 'route-1',
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.route,
      sourceEntityId: 'route-1',
      createdAtUtc: DateTime.utc(2026, 10, 2),
    );

    expect(
      () => LifeBridgeV1Adapter.fromEnvelope(
        envelope,
        transferMode: LifeBridgeTransferMode.copy,
      ),
      throwsUnsupportedError,
    );
  });
}
