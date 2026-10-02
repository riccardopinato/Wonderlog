import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_codec.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';

void main() {
  test('ecosystem envelope round-trips without changing identity', () {
    final original = EcosystemEnvelope(
      id: 'transfer-1',
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
    );

    final restored = EcosystemCodec.decode(EcosystemCodec.encode(original));

    expect(restored.schemaVersion, 1);
    expect(restored.sourceApp, EcosystemAppId.wonderlog);
    expect(restored.sourceEntityId, 'memory-42');
    expect(restored.tags, original.tags);
    expect(restored.places.single.name, 'Cascate di Riva');
    expect(
      restored.idempotencyKey,
      'wonderlog:memory:memory-42:1',
    );
  });

  test('unsupported schema versions fail closed', () {
    expect(
      () => EcosystemEnvelope.fromJson({
        'schemaVersion': 99,
        'id': 'x',
      }),
      throwsFormatException,
    );
  });
}
