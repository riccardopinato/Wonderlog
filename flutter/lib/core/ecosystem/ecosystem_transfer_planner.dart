import 'ecosystem_envelope.dart';
import 'ecosystem_models.dart';
import 'ecosystem_registry.dart';

abstract final class EcosystemTransferPlanner {
  static bool canSend(
    EcosystemEnvelope envelope,
    EcosystemAppId target, {
    required EcosystemRegistry registry,
  }) {
    if (envelope.privacyScope != EcosystemPrivacyScope.explicitShare) {
      return false;
    }

    return registry
        .check(
          targetApp: target,
          envelope: envelope,
        )
        .isCompatible;
  }
}
