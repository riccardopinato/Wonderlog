import 'dart:convert';

import 'ecosystem_envelope.dart';
import 'ecosystem_models.dart';

const String lifeBridgeProtocolVersion = '1.0';

enum LifeBridgeTransferMode { copy, link }

final class LifeBridgeV1Payload {
  const LifeBridgeV1Payload({
    required this.bridgeId,
    required this.source,
    required this.objectType,
    required this.transferMode,
    required this.title,
    required this.text,
    required this.occurredAt,
    required this.people,
    required this.tags,
    required this.exportedAt,
    this.location,
    this.media = const [],
    this.extensions = const {},
  });

  final String bridgeId;
  final Map<String, Object?> source;
  final String objectType;
  final LifeBridgeTransferMode transferMode;
  final String title;
  final String text;
  final DateTime occurredAt;
  final Map<String, Object?>? location;
  final List<Map<String, Object?>> media;
  final List<String> people;
  final List<String> tags;
  final Map<String, Object?> extensions;
  final DateTime exportedAt;

  Map<String, Object?> toJson() => {
        'protocolVersion': lifeBridgeProtocolVersion,
        'bridgeId': bridgeId,
        'source': source,
        'objectType': objectType,
        'transferMode': transferMode.name,
        'title': title,
        'text': text,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        if (location != null) 'location': location,
        'media': media,
        'people': people,
        'tags': tags,
        if (extensions.isNotEmpty) 'extensions': extensions,
        'exportedAt': exportedAt.toUtc().toIso8601String(),
      };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

abstract final class LifeBridgeV1Adapter {
  static LifeBridgeV1Payload fromEnvelope(
    EcosystemEnvelope envelope, {
    required LifeBridgeTransferMode transferMode,
    DateTime? exportedAt,
    Map<String, Object?> extensions = const {},
  }) {
    if (envelope.privacyScope != EcosystemPrivacyScope.explicitShare) {
      throw StateError(
        'Life Bridge export requires explicitShare privacy scope.',
      );
    }

    final objectType = switch (envelope.sourceEntityType) {
      EcosystemEntityType.journey => 'journey',
      EcosystemEntityType.memory => 'travel_memory',
      EcosystemEntityType.note => 'moment',
      EcosystemEntityType.place => 'place',
      EcosystemEntityType.photo => 'photo',
      EcosystemEntityType.route || EcosystemEntityType.generic =>
        throw UnsupportedError(
          'Anna Life Bridge v1 does not accept '
          '${envelope.sourceEntityType.name}.',
        ),
    };

    final place = envelope.places.isEmpty ? null : envelope.places.first;
    final media = envelope.media
        .map(
          (item) => <String, Object?>{
            'kind': item.kind,
            if (item.mimeType != null) 'mimeType': item.mimeType,
            if (item.fileName != null) 'fileName': item.fileName,
            'transfer': 'omitted',
          },
        )
        .toList(growable: false);

    final bridgeId =
        'life-bridge:v1:${envelope.sourceApp.wireValue}:'
        '${envelope.sourceEntityType.name}:'
        '${envelope.sourceEntityId}:'
        '${envelope.revision}';

    return LifeBridgeV1Payload(
      bridgeId: bridgeId,
      source: <String, Object?>{
        'appId': envelope.sourceApp.wireValue,
        'objectId': envelope.sourceEntityId,
        if (envelope.sourceDeepLink != null)
          'deepLink': envelope.sourceDeepLink,
        'revision': envelope.revision.toString(),
      },
      objectType: objectType,
      transferMode: transferMode,
      title: envelope.title?.trim() ?? '',
      text: envelope.text?.trim() ?? '',
      occurredAt: envelope.createdAtUtc,
      location: place == null
          ? null
          : <String, Object?>{
              'name': place.name,
              if (place.latitude != null) 'latitude': place.latitude,
              if (place.longitude != null) 'longitude': place.longitude,
            },
      media: media,
      people: List<String>.unmodifiable(envelope.people),
      tags: List<String>.unmodifiable(envelope.tags),
      extensions: <String, Object?>{
        'wonderlog': <String, Object?>{
          'sourceEnvelopeId': envelope.id,
          'privacyScope': envelope.privacyScope.name,
          'mediaTransfer': media.isEmpty ? 'none' : 'omitted',
          ...extensions,
        },
      },
      exportedAt: (exportedAt ?? DateTime.now()).toUtc(),
    );
  }
}
