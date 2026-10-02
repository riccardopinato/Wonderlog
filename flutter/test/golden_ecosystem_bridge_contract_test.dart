import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_contract_validator.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';

void main() {
  test('Golden candidate wire contains required ownership fields', () {
    final envelope = EcosystemEnvelope(
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'm42',
      createdAtUtc: DateTime.utc(2026, 8, 10),
      title: 'Cascate',
      text: 'Memory text',
      sourceDeepLink: 'wonderlog://memory/m42',
      transferMode: EcosystemTransferMode.link,
      revision: 22,
      provenance: const EcosystemProvenance(
        ownerApp: EcosystemAppId.wonderlog,
        ownerEntityType: EcosystemEntityType.memory,
        ownerEntityId: 'm42',
        ownerRevision: 22,
        canonicalDeepLink: 'wonderlog://memory/m42',
      ),
      media: const [
        EcosystemMediaReference(
          id: 'p1',
          kind: 'photo',
          mimeType: 'image/jpeg',
          fileName: 'photo.jpg',
          byteSize: 1234,
          handoff: EcosystemMediaHandoff(
            kind: EcosystemMediaHandoffKind.omitted,
            reason: 'explicit_binary_handoff_not_enabled_in_v1',
          ),
        ),
      ],
    );

    final json = envelope.toJson();
    final provenance = json['provenance']! as Map<String, Object?>;
    final media = (json['media']! as List).single as Map<String, Object?>;

    expect(json['schemaVersion'], 1);
    expect(json['bridgeId'], 'ecosystem:v1:wonderlog:memory:m42');
    expect(json['transferMode'], 'link');
    expect(json['revision'], 22);
    expect(provenance['ownerApp'], 'wonderlog');
    expect(provenance['ownerEntityId'], 'm42');
    expect(jsonEncode(json), isNot(contains('file://')));
    expect(jsonEncode(json), isNot(contains('content://')));
    expect(media, isNot(contains('localReference')));
    expect(EcosystemContractValidator.validate(envelope).valid, isTrue);
  });

  test('same bridgeId accepts new revision but changes idempotency', () {
    EcosystemEnvelope build(int revision) => EcosystemEnvelope(
          sourceApp: EcosystemAppId.wonderlog,
          sourceEntityType: EcosystemEntityType.journey,
          sourceEntityId: 'j1',
          createdAtUtc: DateTime.utc(2026),
          title: 'Journey',
          sourceDeepLink: 'wonderlog://journey/j1',
          revision: revision,
        );

    final v1 = build(1);
    final v2 = build(2);

    expect(v1.bridgeId, v2.bridgeId);
    expect(v1.idempotencyKey, isNot(v2.idempotencyKey));
  });

  test('LINK without canonical deep link fails closed', () {
    final envelope = EcosystemEnvelope(
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'm1',
      createdAtUtc: DateTime.utc(2026),
      title: 'Memory',
      transferMode: EcosystemTransferMode.link,
      provenance: const EcosystemProvenance(
        ownerApp: EcosystemAppId.wonderlog,
        ownerEntityType: EcosystemEntityType.memory,
        ownerEntityId: 'm1',
        ownerRevision: 1,
      ),
    );

    final result = EcosystemContractValidator.validate(envelope);
    expect(result.valid, isFalse);
    expect(result.reason, 'link_requires_canonical_deep_link');
  });

  test('private media locator fails closed', () {
    final envelope = EcosystemEnvelope(
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: 'm1',
      createdAtUtc: DateTime.utc(2026),
      title: 'Memory',
      media: const [
        EcosystemMediaReference(
          id: 'p1',
          kind: 'photo',
          handoff: EcosystemMediaHandoff(
            kind: EcosystemMediaHandoffKind.cloudObject,
            locator: 'file:///private/photo.jpg',
          ),
        ),
      ],
    );

    final result = EcosystemContractValidator.validate(envelope);
    expect(result.valid, isFalse);
    expect(result.reason, 'private_media_reference_forbidden');
  });
}
