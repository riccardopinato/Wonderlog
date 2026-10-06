import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/features/memories/data/drift_wonderlog_repository.dart';

void main() {
  late WonderlogDatabase database;
  late DriftWonderlogRepository repository;

  setUp(() {
    database = WonderlogDatabase(NativeDatabase.memory());
    repository = DriftWonderlogRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('created journey is emitted by the local repository', () async {
    await repository.createJourney(
      title: 'Valle Aurina 2026',
      destination: 'Campo Tures',
      startDate: DateTime(2026, 8, 10),
      endDate: DateTime(2026, 8, 14),
    );

    final journeys = await repository.watchJourneys().first;

    expect(journeys, hasLength(1));
    expect(journeys.single.title, 'Valle Aurina 2026');
    expect(journeys.single.destination, 'Campo Tures');
  });

  test('invalid date range is rejected before persistence', () async {
    expect(
      () => repository.createJourney(
        title: 'Invalid',
        destination: 'Nowhere',
        startDate: DateTime(2026, 8, 14),
        endDate: DateTime(2026, 8, 10),
      ),
      throwsArgumentError,
    );
  });
}
