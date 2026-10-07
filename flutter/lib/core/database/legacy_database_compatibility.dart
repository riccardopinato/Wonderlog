abstract final class LegacyDatabaseCompatibility {
  static const roomDatabaseName = 'wanderlog-memories-db';
  static const roomSchemaVersion = 6;
  static const flutterSchemaVersion = 9;

  static bool requiresPreMigrationSnapshot(int schemaVersion) =>
      schemaVersion == roomSchemaVersion;

  static bool canOpenLegacyDatabase(int schemaVersion) =>
      schemaVersion == roomSchemaVersion ||
      schemaVersion == flutterSchemaVersion;

  static bool isFutureSchema(int schemaVersion) =>
      schemaVersion > flutterSchemaVersion;

  static List<String> decodeLegacyTags(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return const [];

    // Room's Converters.kt persisted List<String> with "||".
    if (value.contains('||')) {
      return value
          .split('||')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return [value];
  }
}
