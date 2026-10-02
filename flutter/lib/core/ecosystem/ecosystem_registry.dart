import 'ecosystem_models.dart';

enum EcosystemCapability {
  receiveText,
  receivePhoto,
  receivePlace,
  receiveJourney,
  receiveRoute,
}

final class EcosystemAppDefinition {
  const EcosystemAppDefinition({
    required this.id,
    required this.displayName,
    required this.capabilities,
  });

  final EcosystemAppId id;
  final String displayName;
  final Set<EcosystemCapability> capabilities;
}

abstract final class EcosystemRegistry {
  static const apps = <EcosystemAppDefinition>[
    EcosystemAppDefinition(
      id: EcosystemAppId.wonderlog,
      displayName: 'Wonderlog',
      capabilities: {
        EcosystemCapability.receiveText,
        EcosystemCapability.receivePhoto,
        EcosystemCapability.receivePlace,
        EcosystemCapability.receiveJourney,
        EcosystemCapability.receiveRoute,
      },
    ),
    EcosystemAppDefinition(
      id: EcosystemAppId.annasDiary,
      displayName: "Anna's Diary",
      capabilities: {
        EcosystemCapability.receiveText,
        EcosystemCapability.receivePhoto,
        EcosystemCapability.receivePlace,
      },
    ),
    EcosystemAppDefinition(
      id: EcosystemAppId.notes,
      displayName: 'Notes',
      capabilities: {
        EcosystemCapability.receiveText,
        EcosystemCapability.receivePhoto,
      },
    ),
    EcosystemAppDefinition(
      id: EcosystemAppId.trailpath,
      displayName: 'TrailPath',
      capabilities: {
        EcosystemCapability.receivePlace,
        EcosystemCapability.receiveRoute,
      },
    ),
  ];
}
