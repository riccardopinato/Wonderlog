import '../../../core/ecosystem/ecosystem_envelope.dart';
import '../../../core/ecosystem/ecosystem_models.dart';
import '../../../core/ecosystem/life_bridge_v1.dart';
import '../domain/memory_models.dart';

abstract final class MemoryLifeBridgeAdapter {
  static EcosystemEnvelope envelopeFor(
    MemoryEntry memory, {
    List<AlbumPhotoEntry> photos = const [],
  }) {
    final location = memory.locationName.trim();
    final hasCoordinates =
        memory.latitude != null && memory.longitude != null;

    return EcosystemEnvelope(
      id: 'wonderlog:memory:${memory.id}',
      sourceApp: EcosystemAppId.wonderlog,
      sourceEntityType: EcosystemEntityType.memory,
      sourceEntityId: memory.id,
      createdAtUtc: memory.date.toUtc(),
      title: memory.title,
      text: memory.journalText,
      tags: <String>[
        'travel',
        'memory',
        ...memory.tags,
      ],
      places: location.isEmpty && !hasCoordinates
          ? const []
          : [
              EcosystemPlace(
                name: location.isEmpty ? 'Travel place' : location,
                latitude: memory.latitude,
                longitude: memory.longitude,
              ),
            ],
      media: photos
          .map(
            (photo) => EcosystemMediaReference(
              kind: 'photo',
              localReference: photo.localUri,
              mimeType: photo.mimeType,
              fileName: photo.fileName,
            ),
          )
          .toList(growable: false),
      sourceDeepLink: Uri(
        scheme: 'wonderlog',
        host: 'memory',
        pathSegments: [memory.id],
      ).toString(),
      privacyScope: EcosystemPrivacyScope.explicitShare,
      revision: memory.updatedAt.toUtc().millisecondsSinceEpoch,
    );
  }

  static LifeBridgeV1Payload payloadForAnna(
    MemoryEntry memory, {
    List<AlbumPhotoEntry> photos = const [],
    LifeBridgeTransferMode transferMode = LifeBridgeTransferMode.copy,
    DateTime? exportedAt,
  }) =>
      LifeBridgeV1Adapter.fromEnvelope(
        envelopeFor(memory, photos: photos),
        transferMode: transferMode,
        exportedAt: exportedAt,
        extensions: <String, Object?>{
          'journeyId': memory.journeyId,
          'mood': memory.mood.name,
          'favorite': memory.favorite,
        },
      );
}
