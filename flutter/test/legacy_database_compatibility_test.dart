import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/legacy_database_compatibility.dart';

void main() {
  test('legacy Room tags preserve the Kotlin converter format', () {
    expect(
      LegacyDatabaseCompatibility.decodeLegacyTags(
        'trekking||valle aurina||estate',
      ),
      ['trekking', 'valle aurina', 'estate'],
    );
  });

  test('production Room v6 advances to Flutter schema v9', () {
    expect(LegacyDatabaseCompatibility.roomSchemaVersion, 6);
    expect(LegacyDatabaseCompatibility.flutterSchemaVersion, 9);
  });

  test('only certified Room v6 and current Drift v9 may use legacy path', () {
    expect(
      LegacyDatabaseCompatibility.requiresPreMigrationSnapshot(6),
      isTrue,
    );
    expect(
      LegacyDatabaseCompatibility.requiresPreMigrationSnapshot(4),
      isFalse,
    );
    expect(
      LegacyDatabaseCompatibility.requiresPreMigrationSnapshot(5),
      isFalse,
    );
    expect(
      LegacyDatabaseCompatibility.requiresPreMigrationSnapshot(8),
      isFalse,
    );
    expect(
      LegacyDatabaseCompatibility.requiresPreMigrationSnapshot(9),
      isFalse,
    );

    expect(LegacyDatabaseCompatibility.canOpenLegacyDatabase(6), isTrue);
    expect(LegacyDatabaseCompatibility.canOpenLegacyDatabase(9), isTrue);
    expect(LegacyDatabaseCompatibility.canOpenLegacyDatabase(4), isFalse);
    expect(LegacyDatabaseCompatibility.canOpenLegacyDatabase(5), isFalse);
    expect(LegacyDatabaseCompatibility.canOpenLegacyDatabase(8), isFalse);
    expect(LegacyDatabaseCompatibility.isFutureSchema(10), isTrue);
  });
}
