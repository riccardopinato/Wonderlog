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

  Map<String, Object?> toJson() => {
        'kind': kind,
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
