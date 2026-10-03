import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_local_transport.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';

void main() {
  EcosystemTransferPackage package() => EcosystemTransferPackage(
        targetApp: EcosystemAppId.annasDiary,
        createdAtUtc: DateTime.utc(2026, 10, 2),
        envelope: EcosystemEnvelope(
          sourceApp: EcosystemAppId.wonderlog,
          sourceEntityType: EcosystemEntityType.memory,
          sourceEntityId: 'm1',
          createdAtUtc: DateTime.utc(2026, 8, 10),
          title: 'Cascate',
          text: 'Memory',
          sourceDeepLink: 'wonderlog://memory/m1',
          revision: 9,
        ),
      );

  test('portable local package round-trips', () {
    final encoded = EcosystemLocalTransportCodec.encode(package());
    final decoded = EcosystemLocalTransportCodec.decode(encoded);

    expect(decoded.targetApp, EcosystemAppId.annasDiary);
    expect(decoded.envelope.bridgeId, 'ecosystem:v1:wonderlog:memory:m1');
    expect(decoded.envelope.revision, 9);
  });

  test('malformed package fields fail consistently as FormatException', () {
    final valid = package().toJson();

    final unknownTarget = <String, Object?>{
      ...valid,
      'targetApp': 'unknown_app',
    };
    final invalidCreatedAt = <String, Object?>{
      ...valid,
      'createdAtUtc': 'not-a-date',
    };
    final invalidTransportType = <String, Object?>{
      ...valid,
      'transportVersion': '1',
    };

    expect(
      () => EcosystemTransferPackage.fromJson(unknownTarget),
      throwsFormatException,
    );
    expect(
      () => EcosystemTransferPackage.fromJson(invalidCreatedAt),
      throwsFormatException,
    );
    expect(
      () => EcosystemTransferPackage.fromJson(invalidTransportType),
      throwsFormatException,
    );

    final invalidEncoded = base64Url
        .encode(utf8.encode(jsonEncode(unknownTarget)))
        .replaceAll('=', '');
    expect(
      () => EcosystemLocalTransportCodec.decode(invalidEncoded),
      throwsFormatException,
    );
  });

  test('Anna target URI uses explicit ecosystem import route', () {
    final uri = EcosystemLocalTransportCodec.targetUri(package());
    expect(uri.scheme, 'annasdiary');
    expect(uri.host, 'ecosystem');
    expect(uri.path, '/import');
    expect(uri.queryParameters['payload'], isNotEmpty);
  });

  test('target URI round-trips through the shared decoder', () {
    final uri = EcosystemLocalTransportCodec.targetUri(package());
    final decoded = EcosystemLocalTransportCodec.decodeTargetUri(uri);
    expect(decoded.targetApp, EcosystemAppId.annasDiary);
    expect(decoded.envelope.sourceEntityId, 'm1');
  });

  test('clipboard fallback remains machine-readable and portable', () {
    final value = EcosystemLocalTransportCodec.clipboardText(package());
    expect(value, startsWith(ecosystemClipboardPrefix));
    final decoded =
        EcosystemLocalTransportCodec.decodeClipboardText(value);
    expect(decoded.envelope.sourceEntityId, 'm1');
  });
}
