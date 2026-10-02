import 'ecosystem_envelope.dart';
import 'ecosystem_models.dart';
import 'ecosystem_registry.dart';

abstract final class EcosystemTransferPlanner {
  static bool canSend(
    EcosystemEnvelope envelope,
    EcosystemAppId target,
  ) {
    EcosystemAppDefinition? definition;
    for (final app in EcosystemRegistry.apps) {
      if (app.id == target) {
        definition = app;
        break;
      }
    }
    if (definition == null) return false;

    final requiredCapability = switch (envelope.sourceEntityType) {
      EcosystemEntityType.journey => EcosystemCapability.receiveJourney,
      EcosystemEntityType.memory ||
      EcosystemEntityType.note =>
        EcosystemCapability.receiveText,
      EcosystemEntityType.place => EcosystemCapability.receivePlace,
      EcosystemEntityType.route => EcosystemCapability.receiveRoute,
      EcosystemEntityType.photo => EcosystemCapability.receivePhoto,
      EcosystemEntityType.generic => EcosystemCapability.receiveText,
    };

    if (!definition.capabilities.contains(requiredCapability)) {
      return false;
    }

    if (envelope.media.isNotEmpty &&
        !definition.capabilities.contains(EcosystemCapability.receivePhoto) &&
        envelope.sourceEntityType != EcosystemEntityType.journey) {
      return false;
    }

    return envelope.privacyScope == EcosystemPrivacyScope.explicitShare;
  }
}
