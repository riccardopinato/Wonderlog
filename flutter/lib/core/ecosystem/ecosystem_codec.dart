import 'dart:convert';

import 'ecosystem_envelope.dart';

abstract final class EcosystemCodec {
  static String encode(EcosystemEnvelope envelope) =>
      jsonEncode(envelope.toJson());

  static EcosystemEnvelope decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('Invalid EcosystemEnvelope payload.');
    }
    return EcosystemEnvelope.fromJson(decoded);
  }
}
