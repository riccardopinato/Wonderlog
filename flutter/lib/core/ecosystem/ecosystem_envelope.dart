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

  String get idempotencyKey =>
      sourceApp.wireValue +
      ':' +
      sourceEntityType.name +
      ':' +
      sourceEntityId +
      ':' +
      revision.toString();

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
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
      };

  factory EcosystemEnvelope.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion']! as int;
    if (schemaVersion != 1) {
      throw FormatException(
        'Unsupported EcosystemEnvelope schema version: ' +
            schemaVersion.toString(),
      );
    }

    return EcosystemEnvelope(
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
    );
  }
}
