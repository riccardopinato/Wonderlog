import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wonderlog/core/app_controller.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_inbound_transfer_service.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_local_transport_port.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_transfer_service.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_transfer_store.dart';
import 'package:wonderlog/core/identity/identity_models.dart';
import 'package:wonderlog/core/identity/identity_service.dart';
import 'package:wonderlog/core/media/content_addressed_media_asset_store.dart';
import 'package:wonderlog/core/media/memory_media_asset_backend.dart';
import 'package:wonderlog/core/media/source_byte_reader.dart';
import 'package:wonderlog/core/profile/app_profile.dart';
import 'package:wonderlog/core/profile/profile_repository.dart';
import 'package:wonderlog/core/runtime/wonderlog_services_scope.dart';
import 'package:wonderlog/features/ecosystem/presentation/ecosystem_inbox_page.dart';
import 'package:wonderlog/features/journeys/domain/journey.dart';
import 'package:wonderlog/features/location/domain/location_models.dart';
import 'package:wonderlog/features/location/domain/location_repository.dart';
import 'package:wonderlog/features/memories/data/photo_import_service.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';
import 'package:wonderlog/features/memories/domain/wonderlog_repository.dart';
import 'package:wonderlog/features/premium/application/premium_entitlement_service.dart';
import 'package:wonderlog/l10n/app_localizations.dart';

void main() {
  late _Harness harness;

  setUp(() {
    harness = _Harness.create();
  });

  tearDown(() async {
    await harness.dispose();
  });

  testWidgets('E2 UI adds an inbox item to an existing Journey',
      (tester) async {
    final journey = await harness.repository.createJourney(
      title: 'Valle Aurina',
      destination: 'Campo Tures',
      startDate: DateTime(2026, 8, 10),
      endDate: DateTime(2026, 8, 14),
    );
    await harness.receive('ui-existing');
    await harness.pump(tester);

    await _tapVisible(tester, 'Aggiungi a un viaggio esistente');
    await tester.pumpAndSettle();
    await _tapVisible(tester, 'Valle Aurina');
    await tester.pumpAndSettle();

    expect(await harness.repository.watchMemories(journey.id).first, hasLength(1));
    final history = await harness.store.watchInboxHistory().first;
    expect(
      history.single.disposition,
      EcosystemInboxDisposition.addedToJourney,
    );
  });

  testWidgets('E2 UI creates a Journey plus Memory explicitly',
      (tester) async {
    await harness.receive('ui-create');
    await harness.pump(tester);

    await _tapVisible(tester, 'Crea nuovo viaggio');
    await tester.pumpAndSettle();
    await _tapVisible(tester, 'Crea');
    await tester.pumpAndSettle();

    final journeys = await harness.repository.watchJourneys().first;
    expect(journeys, hasLength(1));
    expect(
      await harness.repository.watchMemories(journeys.single.id).first,
      hasLength(1),
    );
    final history = await harness.store.watchInboxHistory().first;
    expect(
      history.single.disposition,
      EcosystemInboxDisposition.createdJourney,
    );
  });

  testWidgets('E2 UI saves a true unassigned Memory', (tester) async {
    await harness.receive('ui-free');
    await harness.pump(tester);

    await _tapVisible(tester, 'Salva come ricordo libero');
    await tester.pumpAndSettle();

    final memories = await harness.repository.watchAllMemories().first;
    expect(memories, hasLength(1));
    expect(memories.single.journeyId, isNull);
    final history = await harness.store.watchInboxHistory().first;
    expect(
      history.single.disposition,
      EcosystemInboxDisposition.savedFreeMemory,
    );
  });

  testWidgets('E2 UI ignores and archives without domain materialization',
      (tester) async {
    await harness.receive('ui-ignore');
    await harness.pump(tester);

    await _tapVisible(tester, 'Ignora e archivia');
    await tester.pumpAndSettle();
    await _tapVisible(tester, 'Conferma');
    await tester.pumpAndSettle();

    expect(await harness.repository.watchJourneys().first, isEmpty);
    expect(await harness.repository.watchAllMemories().first, isEmpty);
    final history = await harness.store.watchInboxHistory().first;
    expect(
      history.single.disposition,
      EcosystemInboxDisposition.ignored,
    );
  });
}

Future<void> _tapVisible(WidgetTester tester, String text) async {
  final finder = find.text(text);
  expect(finder, findsOneWidget);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

final class _Harness {
  _Harness({
    required this.repository,
    required this.store,
    required this.controller,
    required this.services,
  });

  final _MemoryWonderlogRepository repository;
  final _MemoryEcosystemTransferStore store;
  final AppController controller;
  final WonderlogServices services;

  static _Harness create() {
    final repository = _MemoryWonderlogRepository();
    final store = _MemoryEcosystemTransferStore();
    final controller = AppController(
      profileRepository: _TestProfileRepository(),
      identityService: _TestIdentityService(),
      premiumService: PremiumEntitlementService(),
    );
    final port = _TestTransportPort();
    final transferService = EcosystemTransferService(
      store: store,
      localTransport: port,
    );
    final inboundService = EcosystemInboundTransferService(store: store);
    final photoImportService = PhotoImportService(
      mediaStore: ContentAddressedMediaAssetStore(
        MemoryMediaAssetBackend(),
      ),
      byteReader: _TestSourceByteReader(),
    );

    return _Harness(
      repository: repository,
      store: store,
      controller: controller,
      services: WonderlogServices(
        controller: controller,
        repository: repository,
        locationRepository: _TestLocationRepository(),
        photoImportService: photoImportService,
        ecosystemTransferStore: store,
        ecosystemTransferService: transferService,
        ecosystemInboundTransferService: inboundService,
      ),
    );
  }

  Future<void> receive(String sourceId) =>
      store.receiveInbox(
        EcosystemEnvelope(
          sourceApp: EcosystemAppId.annasDiary,
          sourceEntityType: EcosystemEntityType.note,
          sourceEntityId: sourceId,
          createdAtUtc: DateTime.utc(2026, 10, 6, 12),
          title: 'Cena a Campo Tures',
          text: 'Canederli e passeggiata serale.',
          places: const [EcosystemPlace(name: 'Campo Tures')],
          revision: 1,
        ),
      );

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      WonderlogServicesScope(
        services: services,
        child: MaterialApp(
          locale: const Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const EcosystemInboxPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose() async {
    controller.dispose();
    await store.dispose();
  }
}

final class _MemoryEcosystemTransferStore implements EcosystemTransferStore {
  final List<EcosystemInboxItem> _inbox = [];
  final StreamController<List<EcosystemInboxItem>> _changes =
      StreamController<List<EcosystemInboxItem>>.broadcast();
  var _nextId = 1;

  @override
  Stream<List<EcosystemInboxItem>> watchInboxHistory() async* {
    yield List<EcosystemInboxItem>.unmodifiable(_inbox);
    yield* _changes.stream;
  }

  @override
  Stream<List<EcosystemInboxItem>> watchPendingInbox() async* {
    yield _pending();
    await for (final _ in _changes.stream) {
      yield _pending();
    }
  }

  List<EcosystemInboxItem> _pending() => _inbox
      .where((item) => item.isPending)
      .toList(growable: false);

  void _emit() {
    _changes.add(List<EcosystemInboxItem>.unmodifiable(_inbox));
  }

  @override
  Future<void> receiveInbox(EcosystemEnvelope envelope) async {
    _inbox.add(
      EcosystemInboxItem(
        id: 'inbox_${_nextId++}',
        sourceApp: envelope.sourceApp,
        envelope: envelope,
        receivedAt: DateTime.now().toUtc(),
      ),
    );
    _emit();
  }

  @override
  Future<T> materializeInboxExactlyOnce<T>(
    String id, {
    required Future<EcosystemInboxMaterializationCommit<T>> Function()
        materialize,
  }) async {
    final index = _inbox.indexWhere((item) => item.id == id);
    if (index < 0 || !_inbox[index].isPending) {
      throw EcosystemInboxAlreadyResolvedException(id);
    }

    final commit = await materialize();
    final current = _inbox[index];
    _inbox[index] = EcosystemInboxItem(
      id: current.id,
      sourceApp: current.sourceApp,
      envelope: current.envelope,
      receivedAt: current.receivedAt,
      consumedAt: DateTime.now().toUtc(),
      disposition: commit.disposition,
      materializedJourneyId: commit.materializedJourneyId,
      materializedMemoryId: commit.materializedMemoryId,
    );
    _emit();
    return commit.value;
  }

  @override
  Future<void> resolveInbox(
    String id, {
    required EcosystemInboxDisposition disposition,
    required DateTime resolvedAt,
    String? materializedJourneyId,
    String? materializedMemoryId,
  }) async {
    final index = _inbox.indexWhere((item) => item.id == id);
    if (index < 0 || !_inbox[index].isPending) {
      throw EcosystemInboxAlreadyResolvedException(id);
    }
    final current = _inbox[index];
    _inbox[index] = EcosystemInboxItem(
      id: current.id,
      sourceApp: current.sourceApp,
      envelope: current.envelope,
      receivedAt: current.receivedAt,
      consumedAt: resolvedAt,
      disposition: disposition,
      materializedJourneyId: materializedJourneyId,
      materializedMemoryId: materializedMemoryId,
    );
    _emit();
  }

  @override
  Future<void> markInboxConsumed(
    String id, {
    required DateTime consumedAt,
  }) =>
      resolveInbox(
        id,
        disposition: EcosystemInboxDisposition.seenLegacy,
        resolvedAt: consumedAt,
      );

  @override
  Stream<List<EcosystemOutboxItem>> watchPendingOutbox() =>
      const Stream<List<EcosystemOutboxItem>>.empty();

  @override
  Stream<List<EcosystemOutboxItem>> watchOutboxHistory() =>
      const Stream<List<EcosystemOutboxItem>>.empty();

  @override
  Future<String> enqueueOutbox({
    required EcosystemAppId targetApp,
    required EcosystemEnvelope envelope,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> markOutboxDelivered(
    String id, {
    required DateTime deliveredAt,
  }) =>
      throw UnimplementedError();

  @override
  Future<void> markOutboxFailure(
    String id, {
    required String error,
  }) =>
      throw UnimplementedError();

  Future<void> dispose() => _changes.close();
}

final class _MemoryWonderlogRepository implements WonderlogRepository {
  final Map<String, Journey> _journeys = {};
  final Map<String, MemoryEntry> _memories = {};
  var _nextJourneyId = 1;

  @override
  Stream<List<Journey>> watchJourneys() => Stream.value(
        _journeys.values
            .where((journey) => !journey.archived)
            .toList(growable: false),
      );

  @override
  Stream<Journey?> watchJourney(String id) =>
      Stream.value(_journeys[id]);

  @override
  Stream<List<Journey>> watchArchivedJourneys() => Stream.value(
        _journeys.values
            .where((journey) => journey.archived)
            .toList(growable: false),
      );

  @override
  Stream<List<MemoryEntry>> watchMemories(String journeyId) => Stream.value(
        _memories.values
            .where((memory) => memory.journeyId == journeyId)
            .toList(growable: false),
      );

  @override
  Stream<List<MemoryEntry>> watchAllMemories() =>
      Stream.value(_memories.values.toList(growable: false));

  @override
  Stream<List<MemoryEntry>> watchUnassignedMemories() => Stream.value(
        _memories.values
            .where((memory) => memory.journeyId == null)
            .toList(growable: false),
      );

  @override
  Stream<List<MemoryWithPhotos>> watchAllMemoriesWithPhotos() =>
      Stream.value(
        _memories.values
            .map(
              (memory) => MemoryWithPhotos(
                memory: memory,
                photos: const [],
              ),
            )
            .toList(growable: false),
      );

  @override
  Future<Journey> createJourney({
    required String title,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    String country = '',
    String description = '',
  }) async {
    final now = DateTime.now().toUtc();
    final journey = Journey(
      id: 'journey_${_nextJourneyId++}',
      title: title.trim(),
      destination: destination.trim(),
      country: country.trim(),
      startDate: startDate,
      endDate: endDate,
      description: description.trim(),
      latitude: 0,
      longitude: 0,
      favorite: false,
      archived: false,
      createdAt: now,
      updatedAt: now,
    );
    _journeys[journey.id] = journey;
    return journey;
  }

  @override
  Future<void> saveJourney(Journey journey) async {
    _journeys[journey.id] = journey;
  }

  @override
  Future<void> setJourneyArchived(String journeyId, bool archived) async {
    final journey = _journeys[journeyId];
    if (journey == null) return;
    _journeys[journeyId] = Journey(
      id: journey.id,
      title: journey.title,
      destination: journey.destination,
      country: journey.country,
      startDate: journey.startDate,
      endDate: journey.endDate,
      description: journey.description,
      latitude: journey.latitude,
      longitude: journey.longitude,
      favorite: journey.favorite,
      archived: archived,
      createdAt: journey.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<JourneyDeletionImpact> getJourneyDeletionImpact(
    String journeyId,
  ) async => JourneyDeletionImpact(
        memoryCount: _memories.values
            .where((memory) => memory.journeyId == journeyId)
            .length,
        photoCount: 0,
        attachmentCount: 0,
      );

  @override
  Future<void> deleteJourney(String journeyId) async {
    _journeys.remove(journeyId);
    _memories.removeWhere((_, memory) => memory.journeyId == journeyId);
  }

  @override
  Future<void> saveMemory(MemoryEntry memory) async {
    _memories[memory.id] = memory;
  }

  @override
  Future<void> moveMemoryToJourney(
    String memoryId,
    String? journeyId,
  ) async {
    final memory = _memories[memoryId];
    if (memory == null) return;
    _memories[memoryId] = MemoryEntry(
      id: memory.id,
      journeyId: journeyId,
      title: memory.title,
      journalText: memory.journalText,
      locationName: memory.locationName,
      date: memory.date,
      mood: memory.mood,
      tags: memory.tags,
      latitude: memory.latitude,
      longitude: memory.longitude,
      favorite: memory.favorite,
      createdAt: memory.createdAt,
      updatedAt: DateTime.now().toUtc(),
      displayOrder: memory.displayOrder,
      syncStatus: memory.syncStatus,
      futureCloudId: memory.futureCloudId,
    );
  }

  @override
  Future<void> deleteMemory(String memoryId) async {
    _memories.remove(memoryId);
  }

  @override
  Stream<List<MemoryWithPhotos>> watchMemoriesWithPhotos(String journeyId) =>
      Stream.value(
        _memories.values
            .where((memory) => memory.journeyId == journeyId)
            .map(
              (memory) => MemoryWithPhotos(
                memory: memory,
                photos: const [],
              ),
            )
            .toList(growable: false),
      );

  @override
  Stream<MemoryWithPhotos?> watchMemory(String memoryId) => Stream.value(
        _memories[memoryId] == null
            ? null
            : MemoryWithPhotos(
                memory: _memories[memoryId]!,
                photos: const [],
              ),
      );

  @override
  Stream<List<AlbumPhotoEntry>> watchAlbum(String journeyId) =>
      Stream.value(const []);

  @override
  Stream<List<AlbumPhotoEntry>> watchAllPhotos() =>
      Stream.value(const []);

  @override
  Stream<List<MemoryAttachment>> watchAttachments(String memoryId) =>
      Stream.value(const []);

  @override
  Future<void> savePhoto(AlbumPhotoEntry photo) async =>
      throw UnimplementedError();

  @override
  Future<void> deletePhoto(String photoId) async =>
      throw UnimplementedError();

  @override
  Future<void> linkPhotoToMemory({
    required String memoryId,
    required String photoId,
    required int displayOrder,
    required bool isHero,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> replaceMemoryPhotoLinks({
    required String memoryId,
    required List<String> photoIds,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> unlinkPhotoFromMemory({
    required String memoryId,
    required String photoId,
  }) async {}

  @override
  Future<void> setJourneyCoverPhoto({
    required String journeyId,
    String? photoId,
  }) async {}

  @override
  Future<Set<String>> referencedMediaUris() async => <String>{};

  @override
  Future<void> saveAttachment(MemoryAttachment attachment) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteAttachment(String attachmentId) async =>
      throw UnimplementedError();
}

final class _TestProfileRepository implements ProfileRepository {
  AppProfile value = const AppProfile.defaults();

  @override
  Future<AppProfile> load() async => value;

  @override
  Future<void> save(AppProfile profile) async {
    value = profile;
  }
}

final class _TestIdentityService implements IdentityService {
  IdentitySession _current = const IdentitySession.localOnly();

  @override
  IdentitySession get current => _current;

  @override
  Stream<IdentitySession> watch() => const Stream.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signUpWithEmail({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {
    _current = const IdentitySession.signedOut();
  }

  @override
  Future<void> dispose() async {}
}

final class _TestLocationRepository implements LocationRepository {
  @override
  Future<void> deleteOfflineRegion(String id) async {}

  @override
  Future<void> deletePlace(String id) async {}

  @override
  Future<LocationPlace?> reverseGeocode(
    double latitude,
    double longitude,
  ) async =>
      null;

  @override
  Future<void> saveOfflineRegion(OfflineMapRegion region) async {}

  @override
  Future<void> savePlace(LocationPlace place) async {}

  @override
  Future<List<LocationPlace>> searchPlaces(String query) async => const [];

  @override
  Stream<List<OfflineMapRegion>> watchOfflineRegions() =>
      const Stream.empty();

  @override
  Stream<List<LocationPlace>> watchSavedPlaces() => const Stream.empty();
}

final class _TestSourceByteReader implements SourceByteReader {
  @override
  Future<Uint8List> read(String reference) async => Uint8List(0);
}

final class _TestTransportPort implements EcosystemLocalTransportPort {
  @override
  Future<void> copyPortableFallback(String portablePayload) async {}

  @override
  Future<bool> tryOpen(Uri targetUri) async => false;
}
