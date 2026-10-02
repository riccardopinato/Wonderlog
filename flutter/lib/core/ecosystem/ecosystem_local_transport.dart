import 'dart:convert';

import 'ecosystem_contract_validator.dart';
import 'ecosystem_envelope.dart';
import 'ecosystem_models.dart';
import 'ecosystem_registry.dart';

const int ecosystemLocalTransportVersion = 1;
const String ecosystemClipboardPrefix = 'ECOSYSTEM_BRIDGE_V1:';
const int ecosystemMaxLocalPayloadCharacters = 24576;

final class EcosystemTransferPackage {
  const EcosystemTransferPackage({
    this.transportVersion = ecosystemLocalTransportVersion,
    required this.targetApp,
    required this.envelope,
    required this.createdAtUtc,
  });

  final int transportVersion;
  final EcosystemAppId targetApp;
  final EcosystemEnvelope envelope;
  final DateTime createdAtUtc;

  Map<String, Object?> toJson() => {
        'transportVersion': transportVersion,
        'targetApp': targetApp.wireValue,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
        'envelope': envelope.toJson(),
      };

  factory EcosystemTransferPackage.fromJson(
    Map<String, Object?> json,
  ) {
    final transportVersion =
        (json['transportVersion'] as num?)?.toInt() ?? 1;
    if (transportVersion != ecosystemLocalTransportVersion) {
      throw FormatException(
        'Unsupported ecosystem local transport version: '
        '$transportVersion',
      );
    }

    final envelopeRaw = json['envelope'];
    if (envelopeRaw is! Map) {
      throw const FormatException('Missing ecosystem envelope.');
    }

    final envelope = EcosystemEnvelope.fromJson(
      Map<String, Object?>.from(envelopeRaw),
    );
    EcosystemContractValidator.ensureValid(envelope);

    return EcosystemTransferPackage(
      transportVersion: transportVersion,
      targetApp:
          EcosystemAppId.fromWire(json['targetApp']! as String),
      envelope: envelope,
      createdAtUtc:
          DateTime.parse(json['createdAtUtc']! as String).toUtc(),
    );
  }
}

abstract final class EcosystemLocalTransportCodec {
  static String encode(EcosystemTransferPackage package) {
    EcosystemContractValidator.ensureValid(package.envelope);
    final json = jsonEncode(package.toJson());
    return base64Url.encode(utf8.encode(json)).replaceAll('=', '');
  }

  static EcosystemTransferPackage decode(String encoded) {
    final normalized = encoded.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Empty ecosystem transport payload.');
    }
    final padded = normalized.padRight(
      normalized.length + ((4 - normalized.length % 4) % 4),
      '=',
    );
    final json = utf8.decode(base64Url.decode(padded));
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      throw const FormatException('Invalid ecosystem transport payload.');
    }
    return EcosystemTransferPackage.fromJson(
      Map<String, Object?>.from(decoded),
    );
  }

  static Uri targetUri(EcosystemTransferPackage package) {
    final encoded = encode(package);
    if (encoded.length > ecosystemMaxLocalPayloadCharacters) {
      throw StateError('Ecosystem local payload exceeds URI limit.');
    }
    final target = EcosystemRegistry.definition(package.targetApp);
    return Uri(
      scheme: target.deepLinkScheme,
      host: 'ecosystem',
      path: '/import',
      queryParameters: {'payload': encoded},
    );
  }

  static String clipboardText(EcosystemTransferPackage package) =>
      ecosystemClipboardPrefix + encode(package);

  static EcosystemTransferPackage decodeClipboardText(String value) {
    final normalized = value.trim();
    if (!normalized.startsWith(ecosystemClipboardPrefix)) {
      throw const FormatException(
        'Clipboard does not contain an ecosystem transfer.',
      );
    }
    return decode(normalized.substring(ecosystemClipboardPrefix.length));
  }
}
