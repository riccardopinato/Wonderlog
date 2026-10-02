import '../../../core/ecosystem/ecosystem_envelope.dart';
import '../../../core/ecosystem/ecosystem_models.dart';
import '../../../core/ecosystem/life_bridge_v1.dart';
import '../domain/journey.dart';

abstract final class JourneyLifeBridgeAdapter {
  static EcosystemEnvelope envelopeFor(
    Journey journey, {
    EcosystemTransferMode transferMode = EcosystemTransferMode.copy,
  }) {
    final destination = journey.destination.trim();
    final hasCoordinates = journey.latitude != 0 && journey.longitude != 0;
    final country = journey.country.trim();
    final deepLink = Uri(
      scheme: 'wonderlog',
      host: 'journey',
      pathSegments: [journey.id],
    ).toString();
    final revision = journey.updatedAt.toUtc().millisecondsSinceEpoch;

    return EcosystemEnvelope(
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.journey,
      sourceEntityId: journey.id,
      createdAtUtc: journey.startDate.toUtc(),
      title: journey.title,
      text: journey.description,
      tags: <String>[
        'travel',
        'journey',
        if (country.isNotEmpty) 'country:${country.toLowerCase()}',
      ],
      places: destination.isEmpty
          ? const []
          : [
              EcosystemPlace(
                name: destination,
                latitude: hasCoordinates ? journey.latitude : null,
                longitude: hasCoordinates ? journey.longitude : null,
              ),
            ],
      sourceDeepLink: deepLink,
      privacyScope: EcosystemPrivacyScope.explicitShare,
      transferMode: transferMode,
      revision: revision,
      provenance: EcosystemProvenance(
        ownerApp: EcosystemAppId.wonderlog,
        ownerEntityType: EcosystemEntityType.journey,
        ownerEntityId: journey.id,
        ownerRevision: revision,
        canonicalDeepLink: deepLink,
      ),
      fallback: EcosystemFallback(
        plainText: [
          if (journey.title.trim().isNotEmpty) journey.title.trim(),
          if (destination.isNotEmpty) destination,
          if (journey.description.trim().isNotEmpty)
            journey.description.trim(),
        ].join('\n\n'),
        sourceDeepLink: deepLink,
      ),
    );
  }

  static LifeBridgeV1Payload payloadFor(
    Journey journey, {
    EcosystemTransferMode transferMode = EcosystemTransferMode.copy,
    DateTime? exportedAt,
  }) =>
      LifeBridgeV1Adapter.fromEnvelope(
        envelopeFor(journey, transferMode: transferMode),
        exportedAt: exportedAt,
        extensions: <String, Object?>{
          'endAt': journey.endDate.toUtc().toIso8601String(),
          if (journey.country.trim().isNotEmpty)
            'country': journey.country.trim(),
        },
      );
}
