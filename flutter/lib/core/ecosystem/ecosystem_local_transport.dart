import 'dart:convert';

import 'ecosystem_envelope.dart';
import 'ecosystem_models.dart';
import 'ecosystem_registry.dart';
import 'ecosystem_transfer_store.dart';

const String ecosystemLocalHandoffProtocolVersion = '1.0';

final class EcosystemHandoffPacket {
  const EcosystemHandoffPacket({
    required this.targetApp,
    required this.envelope,
    required this.createdAtUtc,
  });

  final EcosystemAppId targetApp;
  final EcosystemEnvelope envelope;
  final DateTime createdAtUtc;

  Map<String, Object?> toJson() => {
        'protocolVersion': ecosystemLocalHandoffProtocolVersion,
        'targetApp': targetApp.wireValue,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
        'envelope': envelope.toJson(),
      };

  String encode() => jsonEncode(toJson());

  factory EcosystemHandoffPacket.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Invalid ecosystem handoff packet.');
    }

    try {
      final protocolVersion = decoded['protocolVersion'];
      if (protocolVersion is! String) {
        throw const FormatException(
          'Ecosystem handoff protocolVersion must be a string.',
        );
      }
      if (protocolVersion != ecosystemLocalHandoffProtocolVersion) {
        throw FormatException(
          'Unsupported ecosystem handoff protocol: $protocolVersion',
        );
      }

      return EcosystemHandoffPacket(
        targetApp: EcosystemAppId.fromWire(decoded['targetApp']! as String),
        envelope: EcosystemEnvelope.fromJson(
          Map<String, Object?>.from(decoded['envelope']! as Map),
        ),
        createdAtUtc:
            DateTime.parse(decoded['createdAtUtc']! as String).toUtc(),
      );
    } on FormatException {
      rethrow;
    } catch (error) {
      throw FormatException('Invalid ecosystem handoff packet: $error');
    }
  }
}

final class EcosystemHandoffPlan {
  const EcosystemHandoffPlan({
    required this.packet,
    required this.fallbackPayload,
    required this.fallbackText,
    this.destinationUri,
  });

  final EcosystemHandoffPacket packet;
  final String fallbackPayload;
  final String fallbackText;
  final Uri? destinationUri;
}

final class EcosystemTransportException implements Exception {
  const EcosystemTransportException(this.message);

  final String message;

  @override
  String toString() => 'EcosystemTransportException: $message';
}

final class EcosystemLocalTransport {
  EcosystemLocalTransport({
    required this.localApp,
    required this.registry,
    required this.store,
  });

  final EcosystemAppId localApp;
  final EcosystemRegistry registry;
  final EcosystemTransferStore store;

  Future<EcosystemHandoffPlan> prepare({
    required EcosystemAppId targetApp,
    required EcosystemEnvelope envelope,
    required EcosystemTransferMode transferMode,
    DateTime? createdAtUtc,
  }) async {
    if (targetApp == localApp) {
      throw const EcosystemTransportException(
        'Source and target app must be different.',
      );
    }
    if (envelope.sourceApp != localApp) {
      throw const EcosystemTransportException(
        'Local transport can only export data canonically owned by this app.',
      );
    }
    if (envelope.privacyScope != EcosystemPrivacyScope.explicitShare) {
      throw const EcosystemTransportException(
        'Cross-app transfer requires explicitShare privacy scope.',
      );
    }

    final prepared = envelope.copyWith(
      transferMode: transferMode,
      requiredCapabilities: _requiredCapabilitiesFor(
        envelope,
        transferMode,
      ),
    );
    final compatibility = registry.check(
      targetApp: targetApp,
      envelope: prepared,
    );
    if (!compatibility.isCompatible) {
      throw EcosystemTransportException(
        compatibility.reason ?? 'Target app is not compatible.',
      );
    }

    await store.enqueueOutbox(
      targetApp: targetApp,
      envelope: prepared,
    );

    final packet = EcosystemHandoffPacket(
      targetApp: targetApp,
      envelope: prepared,
      createdAtUtc: (createdAtUtc ?? DateTime.now()).toUtc(),
    );
    final encoded = packet.encode();
    final registration = registry.registrationFor(targetApp);

    return EcosystemHandoffPlan(
      packet: packet,
      fallbackPayload: encoded,
      fallbackText: prepared.effectiveFallback.plainText,
      destinationUri: registration?.importScheme == null
          ? null
          : _buildDestinationUri(
              scheme: registration!.importScheme!,
              encodedPacket: encoded,
            ),
    );
  }

  Future<void> receiveEncoded(String encodedPacket) async {
    final packet = EcosystemHandoffPacket.decode(encodedPacket);
    await _receive(packet);
  }

  Future<void> receiveUri(Uri uri) async {
    final payload = uri.queryParameters['payload'];
    if (payload == null || payload.isEmpty) {
      throw const FormatException(
        'Ecosystem import URI is missing the payload.',
      );
    }

    final bytes = base64Url.decode(payload);
    await receiveEncoded(utf8.decode(bytes));
  }

  Future<void> _receive(EcosystemHandoffPacket packet) async {
    if (packet.targetApp != localApp) {
      throw const EcosystemTransportException(
        'Handoff packet targets a different app.',
      );
    }
    if (packet.envelope.privacyScope !=
        EcosystemPrivacyScope.explicitShare) {
      throw const EcosystemTransportException(
        'Private data cannot cross the ecosystem boundary.',
      );
    }

    final prepared = packet.envelope.copyWith(
      requiredCapabilities: _requiredCapabilitiesFor(
        packet.envelope,
        packet.envelope.transferMode,
      ),
    );
    final compatibility = registry.check(
      targetApp: localApp,
      envelope: prepared,
    );
    if (!compatibility.isCompatible) {
      throw EcosystemTransportException(
        compatibility.reason ?? 'Incoming packet is not compatible.',
      );
    }

    await store.receiveInbox(prepared);
  }

  Set<EcosystemCapability> _requiredCapabilitiesFor(
    EcosystemEnvelope envelope,
    EcosystemTransferMode transferMode,
  ) =>
      {
        ...envelope.requiredCapabilities,
        if (transferMode == EcosystemTransferMode.copy)
          EcosystemCapability.copy
        else
          EcosystemCapability.link,
        if (envelope.places.isNotEmpty) EcosystemCapability.places,
        if (envelope.people.isNotEmpty) EcosystemCapability.people,
        if (envelope.media.isNotEmpty) EcosystemCapability.mediaMetadata,
        if (envelope.sourceDeepLink != null)
          EcosystemCapability.sourceDeepLink,
        if (!envelope.effectiveFallback.isEmpty)
          EcosystemCapability.fallbackText,
      };

  Uri _buildDestinationUri({
    required String scheme,
    required String encodedPacket,
  }) =>
      Uri(
        scheme: scheme,
        host: 'ecosystem-import',
        queryParameters: {
          'v': ecosystemLocalHandoffProtocolVersion,
          'payload': base64Url.encode(utf8.encode(encodedPacket)),
        },
      );
}
