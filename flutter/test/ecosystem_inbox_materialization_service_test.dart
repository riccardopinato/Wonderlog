import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/core/ecosystem/drift_ecosystem_transfer_store.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_transfer_store.dart';
import 'package:wonderlog/features/ecosystem/application/ecosystem_inbox_materialization_service.dart';
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

  test('concurrent E2 materialization is exactly once', () async {
    final item = await _receive(store, 'note-concurrent');

    final results = await Future.wait<Object>(
      [
        service.saveFreeMemory(item),
        service.saveFreeMemory(item),
      ].map(
        (future) async {
          try {
            return await future;
          } catch (error) {
            return error;
          }
        },
      ),
    );

    final successes =
        results.whereType<EcosystemInboxMaterializationResult>().toList();
    final rejected =
        results.whereType<EcosystemInboxAlreadyResolvedException>().toList();

    expect(successes, hasLength(1));
    expect(rejected, hasLength(1));
    expect(await repository.countUnassignedMemories(), 1);

    final history = await store.watchInboxHistory().first;
    expect(history, hasLength(1));
    expect(
      history.single.disposition,
      EcosystemInboxDisposition.savedFreeMemory,
    );
    expect(history.single.materializedMemoryId, isNotNull);
  });

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
