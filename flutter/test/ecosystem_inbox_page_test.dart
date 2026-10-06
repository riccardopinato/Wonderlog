import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wonderlog/core/app_controller.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/core/ecosystem/drift_ecosystem_transfer_store.dart';
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
import 'package:wonderlog/features/location/domain/location_models.dart';
import 'package:wonderlog/features/location/domain/location_repository.dart';
import 'package:wonderlog/features/memories/data/drift_wonderlog_repository.dart';
import 'package:wonderlog/features/memories/data/photo_import_service.dart';
import 'package:wonderlog/features/premium/application/premium_entitlement_service.dart';
import 'package:wonderlog/l10n/app_localizations.dart';

void main() {
  late _Harness harness;

  setUp(() async {
    harness = await _Harness.create();
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

    await tester.tap(find.text('Aggiungi a un viaggio esistente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Valle Aurina'));
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

    await tester.tap(find.text('Crea nuovo viaggio'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crea'));
    await tester.pumpAndSettle();

    final journeys = await harness.repository.watchJourneys().first;
    expect(journeys, hasLength(1));
    expect(await harness.repository.watchMemories(journeys.single.id).first, hasLength(1));
    final history = await harness.store.watchInboxHistory().first;
    expect(
      history.single.disposition,
      EcosystemInboxDisposition.createdJourney,
    );
  });

  testWidgets('E2 UI saves a true unassigned Memory', (tester) async {
    await harness.receive('ui-free');
    await harness.pump(tester);

    await tester.tap(find.text('Salva come ricordo libero'));
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

    await tester.tap(find.text('Ignora e archivia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conferma'));
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

final class _Harness {
  _Harness({
    required this.database,
    required this.repository,
    required this.store,
    required this.controller,
    required this.services,
  });

  final WonderlogDatabase database;
  final DriftWonderlogRepository repository;
  final DriftEcosystemTransferStore store;
  final AppController controller;
  final WonderlogServices services;

  static Future<_Harness> create() async {
    final database = WonderlogDatabase(NativeDatabase.memory());
    final repository = DriftWonderlogRepository(database);
    final store = DriftEcosystemTransferStore(database);
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
      database: database,
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
    await database.close();
  }
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
