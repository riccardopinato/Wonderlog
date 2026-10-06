import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/core/ecosystem/drift_ecosystem_transfer_store.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_transfer_store.dart';
import 'package:wonderlog/features/ecosystem/application/ecosystem_inbox_materialization_service.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';
import 'package:wonderlog/features/memories/data/drift_wonderlog_repository.dart';

void main() {
  late WonderlogDatabase database;
  late DriftWonderlogRepository repository;
  late DriftEcosystemTransferStore store;
  late EcosystemInboxMaterializationService service;

  setUp(() {
    database = WonderlogDatabase(NativeDatabase.memory());
    repository = DriftWonderlogRepository(database);
    store = DriftEcosystemTransferStore(database);
    service = EcosystemInboxMaterializationService(
      repository: repository,
      store: store,
      isPremium: () => true,
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('adds an Anna item to an existing Journey and records history',
      () async {
    final journey = await repository.createJourney(
      title: 'Valle Aurina',
      destination: 'Campo Tures',
      startDate: DateTime(2026, 8, 10),
      endDate: DateTime(2026, 8, 14),
    );
    final item = await _receive(store, 'note-existing');

    final result = await service.addToJourney(item, journey.id);

    final memories = await repository.watchMemories(journey.id).first;
    expect(memories, hasLength(1));
    expect(memories.single.title, 'Cena a Campo Tures');
    expect(result.journeyId, journey.id);
    expect(result.memoryId, memories.single.id);

    final history = await store.watchInboxHistory().first;
    expect(history.single.disposition,
        EcosystemInboxDisposition.addedToJourney);
    expect(history.single.materializedJourneyId, journey.id);
    expect(history.single.materializedMemoryId, memories.single.id);
    expect(history.single.isPending, isFalse);
  });

  test('saves a true unassigned Memory without creating a hidden Journey',
      () async {
    final item = await _receive(store, 'note-free');

    final result = await service.saveFreeMemory(item);

    final journeys = await repository.watchJourneys().first;
    final memories = await repository.watchAllMemories().first;
    expect(journeys, isEmpty);
    expect(memories, hasLength(1));
    expect(memories.single.journeyId, isNull);
    expect(memories.single.syncStatus, 'LOCAL_ONLY');
    expect(result.disposition,
        EcosystemInboxDisposition.savedFreeMemory);

    final history = await store.watchInboxHistory().first;
    expect(history.single.materializedJourneyId, isNull);
    expect(history.single.materializedMemoryId, memories.single.id);
  });

  test('creates a new Journey plus Memory only after explicit action',
      () async {
    final item = await _receive(store, 'note-new-journey');

    final result = await service.createJourney(
      item: item,
      title: 'Weekend Dolomiti',
      destination: 'Dolomiti',
      startDate: DateTime(2026, 10, 5),
      endDate: DateTime(2026, 10, 5),
    );

    final journeys = await repository.watchJourneys().first;
    expect(journeys, hasLength(1));
    expect(journeys.single.title, 'Weekend Dolomiti');
    final memories =
        await repository.watchMemories(journeys.single.id).first;
    expect(memories, hasLength(1));
    expect(memories.single.journeyId, journeys.single.id);
    expect(result.journeyId, journeys.single.id);
  });

  test('ignore archives transfer without materializing domain data',
      () async {
    final item = await _receive(store, 'note-ignore');

    await service.ignore(item);

    expect(await repository.watchJourneys().first, isEmpty);
    expect(await repository.watchAllMemories().first, isEmpty);
    final history = await store.watchInboxHistory().first;
    expect(history.single.disposition, EcosystemInboxDisposition.ignored);
    expect(history.single.materializedJourneyId, isNull);
    expect(history.single.materializedMemoryId, isNull);
  });

  test('concurrent actions materialize one inbox item exactly once', () async {
    final item = await _receive(store, 'note-race');

    final settled = await Future.wait<Object>([
      _settle(service.saveFreeMemory(item)),
      _settle(service.saveFreeMemory(item)),
    ]);

    expect(
      settled.whereType<EcosystemInboxMaterializationResult>(),
      hasLength(1),
    );
    expect(
      settled.whereType<EcosystemInboxAlreadyResolvedException>(),
      hasLength(1),
    );
    expect(await repository.watchAllMemories().first, hasLength(1));
    expect(await store.watchPendingInbox().first, isEmpty);
  });

  test('failed atomic materialization rolls back domain writes', () async {
    final item = await _receive(store, 'note-rollback');
    final memory = _memory('rollback-memory', journeyId: null);

    await expectLater(
      store.materializeInboxExactlyOnce<void>(
        item.id,
        materialize: () async {
          await repository.saveMemory(memory);
          throw StateError('forced failure');
        },
      ),
      throwsStateError,
    );

    expect(await repository.watchAllMemories().first, isEmpty);
    final pending = await store.watchPendingInbox().first;
    expect(pending.single.id, item.id);
  });

  test('free Memory limits are scoped per Journey and unassigned bucket',
      () async {
    final freeService = EcosystemInboxMaterializationService(
      repository: repository,
      store: store,
      isPremium: () => false,
    );
    final fullJourney = await repository.createJourney(
      title: 'Full',
      destination: 'A',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 1, 2),
    );
    final openJourney = await repository.createJourney(
      title: 'Open',
      destination: 'B',
      startDate: DateTime(2026, 2, 1),
      endDate: DateTime(2026, 2, 2),
    );
    for (var index = 0; index < 5; index++) {
      await repository.saveMemory(
        _memory('full-$index', journeyId: fullJourney.id),
      );
    }

    final openItem = await _receive(store, 'note-open-bucket');
    await freeService.addToJourney(openItem, openJourney.id);
    expect(await repository.watchMemories(openJourney.id).first, hasLength(1));

    final fullItem = await _receive(store, 'note-full-bucket');
    await expectLater(
      freeService.addToJourney(fullItem, fullJourney.id),
      throwsA(isA<EcosystemInboxLimitException>()),
    );

    final firstFree = await _receive(store, 'note-free-bucket');
    await freeService.saveFreeMemory(firstFree);
    for (var index = 0; index < 4; index++) {
      await repository.saveMemory(
        _memory('free-$index', journeyId: null),
      );
    }
    final blockedFree = await _receive(store, 'note-free-blocked');
    await expectLater(
      freeService.saveFreeMemory(blockedFree),
      throwsA(isA<EcosystemInboxLimitException>()),
    );
  });

  test('free Journey limit is enforced inside atomic E2 creation', () async {
    final freeService = EcosystemInboxMaterializationService(
      repository: repository,
      store: store,
      isPremium: () => false,
    );
    for (var index = 0; index < 3; index++) {
      await repository.createJourney(
        title: 'Journey $index',
        destination: 'Destination $index',
        startDate: DateTime(2026, index + 1, 1),
        endDate: DateTime(2026, index + 1, 2),
      );
    }
    final item = await _receive(store, 'note-journey-limit');

    await expectLater(
      freeService.createJourney(
        item: item,
        title: 'Fourth',
        destination: 'Blocked',
        startDate: DateTime(2026, 4, 1),
        endDate: DateTime(2026, 4, 2),
      ),
      throwsA(isA<EcosystemInboxLimitException>()),
    );
    final pending = await store.watchPendingInbox().first;
    expect(pending.single.id, item.id);
  });
}

Future<Object> _settle(
  Future<EcosystemInboxMaterializationResult> future,
) async {
  try {
    return await future;
  } catch (error) {
    return error;
  }
}

MemoryEntry _memory(String id, {required String? journeyId}) {
  final now = DateTime.utc(2026, 10, 6, 12);
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

Future<EcosystemInboxItem> _receive(
  DriftEcosystemTransferStore store,
  String sourceId,
) async {
  await store.receiveInbox(
    EcosystemEnvelope(
      sourceApp: EcosystemAppId.annasDiary,
      sourceEntityType: EcosystemEntityType.note,
      sourceEntityId: sourceId,
      createdAtUtc: DateTime.utc(2026, 10, 5, 14),
      title: 'Cena a Campo Tures',
      text: 'Canederli e passeggiata serale.',
      tags: const ['travel'],
      places: const [
        EcosystemPlace(name: 'Campo Tures'),
      ],
      sourceDeepLink: 'annasdiary://moment/$sourceId',
      transferMode: EcosystemTransferMode.link,
      revision: 1,
    ),
  );
  final pending = await store.watchPendingInbox().first;
  return pending.singleWhere(
    (item) => item.envelope.sourceEntityId == sourceId,
  );
}
