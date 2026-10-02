import 'ecosystem_models.dart';

final class EcosystemEnvelope {
  const EcosystemEnvelope({
    this.schemaVersion = 1,
    required this.id,
    required this.sourceApp,
    required this.sourceEntityType,
    required this.sourceEntityId,
    required this.createdAtUtc,
    this.title,
    this.text,
    this.tags = const [],
    this.people = const [],
    this.places = const [],
    this.media = const [],
    this.sourceDeepLink,
    this.privacyScope = EcosystemPrivacyScope.explicitShare,
    this.revision = 1,
    this.transferMode = EcosystemTransferMode.copy,
    this.requiredCapabilities = const {},
    this.provenance,
    this.fallback,
  });

  final int schemaVersion;
  final String id;
  final EcosystemAppId sourceApp;
  final EcosystemEntityType sourceEntityType;
  final String sourceEntityId;
  final DateTime createdAtUtc;
  final String? title;
  final String? text;
  final List<String> tags;
  final List<String> people;
  final List<EcosystemPlace> places;
  final List<EcosystemMediaReference> media;
  final String? sourceDeepLink;
  final EcosystemPrivacyScope privacyScope;
  final int revision;
  final EcosystemTransferMode transferMode;
  final Set<EcosystemCapability> requiredCapabilities;
  final EcosystemProvenance? provenance;
  final EcosystemFallback? fallback;

  String get bridgeId =>
      'ecosystem:v1:${sourceApp.wireValue}:${sourceEntityType.name}:'
      '$sourceEntityId:$revision';

  String get idempotencyKey =>
      '${sourceApp.wireValue}:${sourceEntityType.name}:$sourceEntityId:$revision';

  String get handoffIdempotencyKey =>
      '$idempotencyKey:${transferMode.name}';

  EcosystemProvenance get effectiveProvenance =>
      provenance ??
      EcosystemProvenance(
        canonicalApp: sourceApp,
        canonicalEntityType: sourceEntityType,
        canonicalEntityId: sourceEntityId,
        canonicalRevision: revision,
      );

  EcosystemFallback get effectiveFallback =>
      fallback ?? EcosystemFallback(title: title, text: text);

  EcosystemEnvelope copyWith({
    EcosystemTransferMode? transferMode,
    Set<EcosystemCapability>? requiredCapabilities,
    EcosystemProvenance? provenance,
    EcosystemFallback? fallback,
  }) =>
      EcosystemEnvelope(
        schemaVersion: schemaVersion,
        id: id,
        sourceApp: sourceApp,
        sourceEntityType: sourceEntityType,
        sourceEntityId: sourceEntityId,
        createdAtUtc: createdAtUtc,
        title: title,
        text: text,
        tags: tags,
        people: people,
        places: places,
        media: media,
        sourceDeepLink: sourceDeepLink,
        privacyScope: privacyScope,
        revision: revision,
        transferMode: transferMode ?? this.transferMode,
        requiredCapabilities:
            requiredCapabilities ?? this.requiredCapabilities,
        provenance: provenance ?? this.provenance,
        fallback: fallback ?? this.fallback,
      );

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'bridgeId': bridgeId,
        'sourceApp': sourceApp.wireValue,
        'sourceEntityType': sourceEntityType.name,
        'sourceEntityId': sourceEntityId,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
        'title': title,
        'text': text,
        'tags': tags,
        'people': people,
        'places': places.map((item) => item.toJson()).toList(),
        'media': media.map((item) => item.toJson()).toList(),
        'sourceDeepLink': sourceDeepLink,
        'privacyScope': privacyScope.name,
        'revision': revision,
        'transferMode': transferMode.name,
        'requiredCapabilities':
            requiredCapabilities.map((item) => item.name).toList(),
        'provenance': effectiveProvenance.toJson(),
        'fallback': effectiveFallback.toJson(),
      };

  factory EcosystemEnvelope.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion']! as int;
    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported EcosystemEnvelope schema version: $schemaVersion',
      );
    }

    final envelope = EcosystemEnvelope(
      schemaVersion: schemaVersion,
      id: json['id']! as String,
      sourceApp: EcosystemAppId.fromWire(json['sourceApp']! as String),
      sourceEntityType: EcosystemEntityType.values.byName(
        json['sourceEntityType']! as String,
      ),
      sourceEntityId: json['sourceEntityId']! as String,
      createdAtUtc: DateTime.parse(json['createdAtUtc']! as String).toUtc(),
      title: json['title'] as String?,
      text: json['text'] as String?,
      tags: List<String>.unmodifiable(
        (json['tags'] as List<Object?>? ?? const []).whereType<String>(),
      ),
      people: List<String>.unmodifiable(
        (json['people'] as List<Object?>? ?? const []).whereType<String>(),
      ),
      places: List<EcosystemPlace>.unmodifiable(
        (json['places'] as List<Object?>? ?? const []).map(
          (item) => EcosystemPlace.fromJson(
            Map<String, Object?>.from(item! as Map),
          ),
        ),
      ),
      media: List<EcosystemMediaReference>.unmodifiable(
        (json['media'] as List<Object?>? ?? const []).map(
          (item) => EcosystemMediaReference.fromJson(
            Map<String, Object?>.from(item! as Map),
          ),
        ),
      ),
      sourceDeepLink: json['sourceDeepLink'] as String?,
      privacyScope: EcosystemPrivacyScope.values.byName(
        json['privacyScope'] as String? ?? 'explicitShare',
      ),
      revision: json['revision'] as int? ?? 1,
      transferMode: EcosystemTransferMode.values.byName(
        json['transferMode'] as String? ?? 'copy',
      ),
      requiredCapabilities: Set<EcosystemCapability>.unmodifiable(
        (json['requiredCapabilities'] as List<Object?>? ?? const [])
            .whereType<String>()
            .map(EcosystemCapability.values.byName),
      ),
      provenance: json['provenance'] == null
          ? null
          : EcosystemProvenance.fromJson(
              Map<String, Object?>.from(json['provenance']! as Map),
            ),
      fallback: json['fallback'] == null
          ? null
          : EcosystemFallback.fromJson(
              Map<String, Object?>.from(json['fallback']! as Map),
            ),
    );

    final encodedBridgeId = json['bridgeId'] as String?;
    if (encodedBridgeId != null && encodedBridgeId != envelope.bridgeId) {
      throw const FormatException(
        'EcosystemEnvelope bridgeId does not match source identity.',
      );
    }

    return envelope;
  }
}
