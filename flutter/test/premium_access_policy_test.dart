import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart'
    hide MemoryAttachment;
import 'package:wonderlog/features/memories/data/drift_wonderlog_repository.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';
import 'package:wonderlog/features/premium/application/premium_access_policy.dart';
import 'package:wonderlog/features/premium/domain/premium_gate.dart';
import 'package:wonderlog/features/premium/domain/subscription_config.dart';

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

  PremiumAccessPolicy policy({required bool premium}) => PremiumAccessPolicy(
        repository: repository,
        isPremium: () => premium,
      );

  Future<String> createJourney(String suffix) async {
    final journey = await repository.createJourney(
      title: 'Journey $suffix',
      destination: 'Destination $suffix',
      startDate: DateTime.utc(2026, 10, 1),
      endDate: DateTime.utc(2026, 10, 2),
    );
    return journey.id;
  }

  Future<void> createMemory({
    required String id,
    required String? journeyId,
  }) async {
    final now = DateTime.utc(2026, 10, 6);
    await repository.saveMemory(
      MemoryEntry(
        id: id,
        journeyId: journeyId,
        title: id,
        journalText: '',
        locationName: '',
        date: now,
        mood: Mood.calm,
        tags: const [],
        favorite: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  test('Free Journey quota counts archived Journeys', () async {
    final first = await createJourney('1');
    await createJourney('2');
    await createJourney('3');
    await repository.setJourneyArchived(first, true);

    final result = await policy(premium: false).canCreateJourney();

    expect(result, isA<PremiumLimitReached>());
    final limit = result as PremiumLimitReached;
    expect(limit.current, SubscriptionConfig.freeJourneysLimit);
    expect(limit.limit, SubscriptionConfig.freeJourneysLimit);
  });

  test('Memory quota is scoped per Journey and unassigned bucket', () async {
    final fullJourney = await createJourney('full');
    final freeJourney = await createJourney('free');

    for (var index = 0;
        index < SubscriptionConfig.freeMemoriesPerJourney;
        index++) {
      await createMemory(
        id: 'full-$index',
        journeyId: fullJourney,
      );
    }
    for (var index = 0;
        index < SubscriptionConfig.freeUnassignedMemories - 1;
        index++) {
      await createMemory(
        id: 'unassigned-$index',
        journeyId: null,
      );
    }

    final free = policy(premium: false);

    expect(
      await free.canCreateMemory(journeyId: fullJourney),
      isA<PremiumLimitReached>(),
    );
    expect(
      await free.canCreateMemory(journeyId: freeJourney),
      isA<PremiumAllowed>(),
    );
    expect(
      await free.canCreateMemory(journeyId: null),
      isA<PremiumAllowed>(),
    );

    await createMemory(
      id: 'unassigned-last',
      journeyId: null,
    );

    expect(
      await free.canCreateMemory(journeyId: null),
      isA<PremiumLimitReached>(),
    );
  });

  test('Premium is unlimited for creation but Album remains capped at 100',
      () async {
    final premium = policy(premium: true);

    expect(
      premium.canCreateMemoryForCount(1000000),
      isA<PremiumAllowed>(),
    );

    final photos = premium.photoImportAllowance(
      currentCount: 99,
      selectedCount: 3,
    );
    expect(photos.limit, SubscriptionConfig.premiumAlbumPhotosPerJourney);
    expect(photos.allowedCount, 1);
    expect(photos.blockedCount, 2);
  });

  test('Free batch Memory allowance is deterministic for Smart Journey',
      () async {
    final free = policy(premium: false);

    final memories = free.memoryCreationAllowanceForCount(
      currentCount: 0,
      selectedCount: SubscriptionConfig.freeMemoriesPerJourney + 2,
    );

    expect(
      memories.allowedCount,
      SubscriptionConfig.freeMemoriesPerJourney,
    );
    expect(memories.blockedCount, 2);
    expect(memories.isFullyAllowed, isFalse);
  });
}
