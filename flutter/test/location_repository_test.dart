import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/features/location/data/open_street_map_repository.dart';

void main() {
  test('blank place search remains local and returns empty', () async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final repository = OpenStreetMapRepository(database);
    expect(await repository.searchPlaces('   '), isEmpty);
    await database.close();
  });
}
