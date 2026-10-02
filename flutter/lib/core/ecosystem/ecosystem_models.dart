enum EcosystemAppId {
  wonderlog('wonderlog'),
  annasDiary('annas_diary'),
  notes('notes'),
  trailpath('trailpath');

  const EcosystemAppId(this.wireValue);
  final String wireValue;

  static EcosystemAppId fromWire(String value) => values.firstWhere(
        (item) => item.wireValue == value,
      );
}

enum EcosystemEntityType {
  journey,
  memory,
  note,
  place,
  route,
  photo,
  generic,
}

enum EcosystemPrivacyScope {
  private,
  explicitShare,
}

enum EcosystemTransferMode {
  copy,
  link,
}

enum EcosystemCapability {
  copy,
  link,
  places,
  people,
  mediaMetadata,
  sourceDeepLink,
  fallbackText,
}

final class EcosystemPlace {
  const EcosystemPlace({
    required this.name,
    this.latitude,
    this.longitude,
  });

  final String name;
  final double? latitude;
  final double? longitude;

  Map<String, Object?> toJson() => {
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory EcosystemPlace.fromJson(Map<String, Object?> json) =>
      EcosystemPlace(
        name: json['name']! as String,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}

final class EcosystemMediaReference {
  const EcosystemMediaReference({
    required this.kind,
    this.localReference,
    this.mimeType,
    this.fileName,
  });

  final String kind;
  final String? localReference;
  final String? mimeType;
  final String? fileName;

  Map<String, Object?> toJson({
    bool includeLocalReference = false,
  }) =>
      {
        'kind': kind,
        if (includeLocalReference && localReference != null)
          'localReference': localReference,
        'mimeType': mimeType,
        'fileName': fileName,
      };

  factory EcosystemMediaReference.fromJson(Map<String, Object?> json) =>
      EcosystemMediaReference(
        kind: json['kind']! as String,
        localReference: json['localReference'] as String?,
        mimeType: json['mimeType'] as String?,
        fileName: json['fileName'] as String?,
      );
}

final class EcosystemProvenance {
  const EcosystemProvenance({
    required this.canonicalApp,
    required this.canonicalEntityType,
    required this.canonicalEntityId,
    required this.canonicalRevision,
    this.parentBridgeId,
  });

  final EcosystemAppId canonicalApp;
  final EcosystemEntityType canonicalEntityType;
  final String canonicalEntityId;
  final int canonicalRevision;
  final String? parentBridgeId;

  Map<String, Object?> toJson() => {
        'canonicalApp': canonicalApp.wireValue,
        'canonicalEntityType': canonicalEntityType.name,
        'canonicalEntityId': canonicalEntityId,
        'canonicalRevision': canonicalRevision,
        if (parentBridgeId != null) 'parentBridgeId': parentBridgeId,
      };

  factory EcosystemProvenance.fromJson(Map<String, Object?> json) =>
      EcosystemProvenance(
        canonicalApp: EcosystemAppId.fromWire(
          json['canonicalApp']! as String,
        ),
        canonicalEntityType: EcosystemEntityType.values.byName(
          json['canonicalEntityType']! as String,
        ),
        canonicalEntityId: json['canonicalEntityId']! as String,
        canonicalRevision: json['canonicalRevision']! as int,
        parentBridgeId: json['parentBridgeId'] as String?,
      );
}

final class EcosystemFallback {
  const EcosystemFallback({
    this.title,
    this.text,
  });

  final String? title;
  final String? text;

  bool get isEmpty =>
      (title == null || title!.trim().isEmpty) &&
      (text == null || text!.trim().isEmpty);

  String get plainText => [
        if (title != null && title!.trim().isNotEmpty) title!.trim(),
        if (text != null && text!.trim().isNotEmpty) text!.trim(),
      ].join('\n\n');

  Map<String, Object?> toJson() => {
        'title': title,
        'text': text,
      };

  factory EcosystemFallback.fromJson(Map<String, Object?> json) =>
      EcosystemFallback(
        title: json['title'] as String?,
        text: json['text'] as String?,
      );
}
