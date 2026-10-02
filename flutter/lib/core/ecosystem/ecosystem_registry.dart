import 'ecosystem_envelope.dart';
import 'ecosystem_models.dart';

final class EcosystemAppRegistration {
  const EcosystemAppRegistration({
    required this.appId,
    required this.acceptedEntityTypes,
    required this.transferModes,
    required this.capabilities,
    this.importScheme,
  });

  final EcosystemAppId appId;
  final Set<EcosystemEntityType> acceptedEntityTypes;
  final Set<EcosystemTransferMode> transferModes;
  final Set<EcosystemCapability> capabilities;
  final String? importScheme;
}

final class EcosystemCompatibility {
  const EcosystemCompatibility._({
    required this.isCompatible,
    this.reason,
  });

  const EcosystemCompatibility.compatible()
      : this._(isCompatible: true);

  const EcosystemCompatibility.incompatible(String reason)
      : this._(
          isCompatible: false,
          reason: reason,
        );

  final bool isCompatible;
  final String? reason;
}

final class EcosystemRegistry {
  EcosystemRegistry(Iterable<EcosystemAppRegistration> registrations)
      : _registrations = {
          for (final registration in registrations)
            registration.appId: registration,
        };

  final Map<EcosystemAppId, EcosystemAppRegistration> _registrations;

  EcosystemAppRegistration? registrationFor(EcosystemAppId appId) =>
      _registrations[appId];

  EcosystemCompatibility check({
    required EcosystemAppId targetApp,
    required EcosystemEnvelope envelope,
  }) {
    final registration = _registrations[targetApp];
    if (registration == null) {
      return EcosystemCompatibility.incompatible(
        'Target app ${targetApp.wireValue} is not registered.',
      );
    }

    if (!registration.acceptedEntityTypes.contains(
      envelope.sourceEntityType,
    )) {
      return EcosystemCompatibility.incompatible(
        'Target app does not accept ${envelope.sourceEntityType.name}.',
      );
    }

    if (!registration.transferModes.contains(envelope.transferMode)) {
      return EcosystemCompatibility.incompatible(
        'Target app does not support ${envelope.transferMode.name}.',
      );
    }

    final missingCapabilities =
        envelope.requiredCapabilities.difference(registration.capabilities);
    if (missingCapabilities.isNotEmpty) {
      final names = missingCapabilities.map((item) => item.name).join(', ');
      return EcosystemCompatibility.incompatible(
        'Target app is missing required capabilities: $names.',
      );
    }

    return const EcosystemCompatibility.compatible();
  }
}
