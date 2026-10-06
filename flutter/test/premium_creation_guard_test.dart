import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/features/memories/data/drift_wonderlog_repository.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';
import 'package:wonderlog/features/premium/domain/premium_creation_guard.dart';

void main() {
  late WonderlogDatabase database;
  late DriftWonderlogRepository repository;
  late PremiumCreationGuard guard;

  setUp(() {
    database = WonderlogDatabase(NativeDatabase.memory());
    repository = DriftWonderlogRepository(database);
    guard = PremiumCreationGuard(
      repository: repository,
      isPremium: () => false,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('Memory limits are per Journey and separate from unassigned bucket',
      () async {
    final first = await repository.createJourney(
      title: 'First',
      destination: 'A',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 1),
    );
    final second = await repository.createJourney(
      title: 'Second',
      destination: 'B',
      startDate: DateTime(2026, 1, 2),
      endDate: DateTime(2026, 1, 2),
    );

    for (var index = 0; index < 5; index++) {
      await repository.saveMemory(_memory('j1-$index', first.id));
    }
    for (var index = 0; index < 4; index++) {
      await repository.saveMemory(_memory('free-$index', null));
    }

    expect(
      () => guard.ensureMemoryAllowed(journeyId: first.id),
      throwsA(isA<PremiumCreationLimitException>()),
    );
    await guard.ensureMemoryAllowed(journeyId: second.id);
    await guard.ensureMemoryAllowed(journeyId: null);

    await repository.saveMemory(_memory('free-4', null));

    expect(
      () => guard.ensureMemoryAllowed(journeyId: null),
      throwsA(isA<PremiumCreationLimitException>()),
    );
    await guard.ensureMemoryAllowed(journeyId: second.id);
  });

  test('new Journey Memory batch is rejected before partial creation', () {
    guard.ensureNewJourneyMemoryBatchAllowed(requested: 5);
    expect(
      () => guard.ensureNewJourneyMemoryBatchAllowed(requested: 6),
      throwsA(isA<PremiumCreationLimitException>()),
    );
  });
}

MemoryEntry _memory(String id, String? journeyId) {
  final now = DateTime.utc(2026, 10, 6);
  return MemoryEntry(
    id: id,
    journeyId: journeyId,
    title: id,
    journalText: '',
    locationName: '',
    date: now,
    mood: Mood.calm,
    tags: const [],
    createdAt: now,
    updatedAt: now,
  );
}
