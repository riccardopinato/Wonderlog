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

  test('production Room v6 advances to Flutter schema v7', () {
    expect(LegacyDatabaseCompatibility.roomSchemaVersion, 6);
    expect(LegacyDatabaseCompatibility.flutterSchemaVersion, 7);
  });
}
