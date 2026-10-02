import '../../features/journeys/application/journey_life_bridge_adapter.dart';
import '../../features/journeys/domain/journey.dart';
import '../../features/memories/application/memory_life_bridge_adapter.dart';
import '../../features/memories/domain/memory_models.dart';
import 'ecosystem_envelope.dart';
import 'ecosystem_models.dart';

abstract final class WonderlogEcosystemAdapter {
  static EcosystemEnvelope journey(
    Journey value, {
    EcosystemTransferMode mode = EcosystemTransferMode.copy,
  }) =>
      JourneyLifeBridgeAdapter.envelopeFor(
        value,
        transferMode: mode,
      );

  static EcosystemEnvelope memory(
    MemoryEntry value, {
    List<AlbumPhotoEntry> photos = const [],
    EcosystemTransferMode mode = EcosystemTransferMode.copy,
  }) =>
      MemoryLifeBridgeAdapter.envelopeFor(
        value,
        photos: photos,
        transferMode: mode,
      );
}
