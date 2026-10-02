import '../../../core/ecosystem/ecosystem_envelope.dart';
import '../../../core/ecosystem/ecosystem_models.dart';
import '../../../core/ecosystem/life_bridge_v1.dart';
import '../domain/journey.dart';

abstract final class JourneyLifeBridgeAdapter {
  static EcosystemEnvelope envelopeFor(Journey journey) {
    final destination = journey.destination.trim();
    final hasCoordinates = journey.latitude != 0 && journey.longitude != 0;
    final country = journey.country.trim();

    return EcosystemEnvelope(
      id: 'wonderlog:journey:${journey.id}',
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
      sourceDeepLink: Uri(
        scheme: 'wonderlog',
        host: 'journey',
        pathSegments: [journey.id],
      ).toString(),
      privacyScope: EcosystemPrivacyScope.explicitShare,
      revision: journey.updatedAt.toUtc().millisecondsSinceEpoch,
    );
  }

  static LifeBridgeV1Payload payloadFor(
    Journey journey, {
    LifeBridgeTransferMode transferMode = LifeBridgeTransferMode.copy,
    DateTime? exportedAt,
  }) =>
      LifeBridgeV1Adapter.fromEnvelope(
        envelopeFor(journey),
        transferMode: transferMode,
        exportedAt: exportedAt,
        extensions: <String, Object?>{
          'endAt': journey.endDate.toUtc().toIso8601String(),
          if (journey.country.trim().isNotEmpty)
            'country': journey.country.trim(),
        },
      );
}
