import '../../../core/ecosystem/ecosystem_envelope.dart';
import '../../../core/ecosystem/ecosystem_models.dart';
import '../../../core/ecosystem/life_bridge_v1.dart';
import '../domain/memory_models.dart';

abstract final class MemoryLifeBridgeAdapter {
  static EcosystemEnvelope envelopeFor(
    MemoryEntry memory, {
    List<AlbumPhotoEntry> photos = const [],
    EcosystemTransferMode transferMode = EcosystemTransferMode.copy,
  }) {
    final location = memory.locationName.trim();
    final hasCoordinates =
        memory.latitude != null && memory.longitude != null;
    final deepLink = Uri(
      scheme: 'wonderlog',
      host: 'memory',
      pathSegments: [memory.id],
    ).toString();
    final revision = memory.updatedAt.toUtc().millisecondsSinceEpoch;

    return EcosystemEnvelope(
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
              id: photo.id,
              kind: 'photo',
              mimeType: photo.mimeType,
              fileName: photo.fileName,
              byteSize: photo.fileSize,
              handoff: const EcosystemMediaHandoff(
                kind: EcosystemMediaHandoffKind.omitted,
                reason: 'explicit_binary_handoff_not_enabled_in_v1',
              ),
            ),
          )
          .toList(growable: false),
      sourceDeepLink: deepLink,
      privacyScope: EcosystemPrivacyScope.explicitShare,
      transferMode: transferMode,
      revision: revision,
      provenance: EcosystemProvenance(
        ownerApp: EcosystemAppId.wonderlog,
        ownerEntityType: EcosystemEntityType.memory,
        ownerEntityId: memory.id,
        ownerRevision: revision,
        canonicalDeepLink: deepLink,
      ),
      fallback: EcosystemFallback(
        plainText: [
          if (memory.title.trim().isNotEmpty) memory.title.trim(),
          if (location.isNotEmpty) location,
          if (memory.journalText.trim().isNotEmpty)
            memory.journalText.trim(),
        ].join('\n\n'),
        sourceDeepLink: deepLink,
      ),
    );
  }

  static LifeBridgeV1Payload payloadForAnna(
    MemoryEntry memory, {
    List<AlbumPhotoEntry> photos = const [],
    EcosystemTransferMode transferMode = EcosystemTransferMode.copy,
    DateTime? exportedAt,
  }) =>
      LifeBridgeV1Adapter.fromEnvelope(
        envelopeFor(
          memory,
          photos: photos,
          transferMode: transferMode,
        ),
        exportedAt: exportedAt,
        extensions: <String, Object?>{
          'journeyId': memory.journeyId,
          'mood': memory.mood.name,
          'favorite': memory.favorite,
        },
      );
}
