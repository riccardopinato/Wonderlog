import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_codec.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_contract_validator.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';

void main() {
  test('ecosystem envelope round-trips without changing identity', () {
    final original = EcosystemEnvelope(
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'memory-42',
      createdAtUtc: DateTime.utc(2026, 8, 14, 18, 45),
      title: 'Cascate di Riva',
      text: 'Giornata alle cascate',
      tags: const ['valle-aurina', 'trekking'],
      places: const [
        EcosystemPlace(
          name: 'Cascate di Riva',
          latitude: 46.929,
          longitude: 11.956,
        ),
      ],
      sourceDeepLink: 'wonderlog://memory/memory-42',
      revision: 7,
    );

    final restored = EcosystemCodec.decode(EcosystemCodec.encode(original));

    expect(restored.schemaVersion, 1);
    expect(restored.bridgeId, 'ecosystem:v1:wonderlog:memory:memory-42');
    expect(restored.sourceApp, EcosystemAppId.wonderlog);
    expect(restored.sourceEntityId, 'memory-42');
    expect(restored.tags, original.tags);
    expect(restored.places.single.name, 'Cascate di Riva');
    expect(
      restored.idempotencyKey,
      'ecosystem:v1:wonderlog:memory:memory-42:7:copy',
    );
    expect(restored.provenance.ownerApp, EcosystemAppId.wonderlog);
  });

  test('COPY and LINK share bridge identity but not delivery identity', () {
    EcosystemEnvelope build(EcosystemTransferMode mode) => EcosystemEnvelope(
          sourceApp: EcosystemAppId.wonderlog,
          sourceEntityType: EcosystemEntityType.journey,
          sourceEntityId: 'j1',
          createdAtUtc: DateTime.utc(2026),
          title: 'Trip',
          sourceDeepLink: 'wonderlog://journey/j1',
          transferMode: mode,
          revision: 12,
        );

    final copy = build(EcosystemTransferMode.copy);
    final link = build(EcosystemTransferMode.link);

    expect(copy.bridgeId, link.bridgeId);
    expect(copy.idempotencyKey, isNot(link.idempotencyKey));
    expect(EcosystemContractValidator.validate(copy).valid, isTrue);
    expect(EcosystemContractValidator.validate(link).valid, isTrue);
  });

  test('legacy local media references are discarded on decode', () {
    final envelope = EcosystemEnvelope.fromJson({
      'schemaVersion': 1,
      'id': 'legacy',
      'sourceApp': 'wonderlog',
      'sourceEntityType': 'memory',
      'sourceEntityId': 'm1',
      'createdAtUtc': '2026-01-01T00:00:00.000Z',
      'title': 'Memory',
      'media': [
        {
          'kind': 'photo',
          'fileName': 'photo.jpg',
          'localReference': 'file:///private/photo.jpg',
        },
      ],
    });

    final encoded = EcosystemCodec.encode(envelope);
    expect(encoded, isNot(contains('file:///private/photo.jpg')));
    expect(
      envelope.media.single.handoff.kind,
      EcosystemMediaHandoffKind.omitted,
    );
  });

  test('unsupported schema versions fail closed', () {
    expect(
      () => EcosystemEnvelope.fromJson({
        'schemaVersion': 99,
      }),
      throwsFormatException,
    );
  });
}
