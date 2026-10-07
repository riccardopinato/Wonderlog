import 'package:drift/drift.dart';

import 'database_connection.dart';

part 'wonderlog_database.g.dart';

class Trips extends Table {
  @override
  String get tableName => 'trips';

  TextColumn get id => text()();
  TextColumn get destinationName => text().named('destinationName')();
  TextColumn get country => text().withDefault(const Constant(''))();
  TextColumn get startDate => text().named('startDate')();
  TextColumn get endDate => text().named('endDate')();
  TextColumn get coverImage => text().named('coverImage').withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get accentGradientIndex => integer().named('accentGradientIndex').withDefault(const Constant(0))();
  RealColumn get latitude => real().withDefault(const Constant(0))();
  RealColumn get longitude => real().withDefault(const Constant(0))();
  TextColumn get title => text()();
  TextColumn get destination => text()();
  TextColumn get coverPhotoId => text().named('coverPhotoId').withDefault(const Constant(''))();
  TextColumn get accentTheme =>
      text().named('accentTheme').withDefault(const Constant('Preset_0'))();
  IntColumn get createdAt => integer().named('createdAt')();
  IntColumn get updatedAt => integer().named('updatedAt')();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get statistics => text().withDefault(const Constant(''))();
  TextColumn get futureCloudId => text().named('futureCloudId').nullable()();
  TextColumn get syncStatus =>
      text().named('syncStatus').withDefault(const Constant('LOCAL_ONLY'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Memories extends Table {
  @override
  String get tableName => 'memories';

  TextColumn get id => text()();
  TextColumn get tripId =>
      text().named('tripId').nullable().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get journeyId => text().named('journeyId').nullable()();
  TextColumn get title => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get journalText => text().named('journalText').withDefault(const Constant(''))();
  TextColumn get image => text().withDefault(const Constant(''))();
  TextColumn get locationName => text().named('locationName').withDefault(const Constant(''))();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get date => text()();
  TextColumn get mood => text().withDefault(const Constant('HAPPY'))();
  TextColumn get tagsJson =>
      text().named('tags').withDefault(const Constant('[]'))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer().named('createdAt')();
  IntColumn get updatedAt => integer().named('updatedAt')();
  IntColumn get displayOrder => integer().named('displayOrder').withDefault(const Constant(0))();
  TextColumn get syncStatus =>
      text().named('syncStatus').withDefault(const Constant('LOCAL_ONLY'))();
  TextColumn get futureCloudId => text().named('futureCloudId').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class AlbumPhotos extends Table {
  @override
  String get tableName => 'album_photos';

  TextColumn get id => text()();
  TextColumn get journeyId =>
      text().named('journeyId').references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get localUri => text().named('localUri')();
  TextColumn get thumbnailUri => text().named('thumbnailUri').withDefault(const Constant(''))();
  TextColumn get originalUri => text().named('originalUri').withDefault(const Constant(''))();
  TextColumn get fileName => text().named('fileName').withDefault(const Constant(''))();
  TextColumn get mimeType => text().named('mimeType').withDefault(const Constant('image/jpeg'))();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  IntColumn get fileSize => integer().named('fileSize').withDefault(const Constant(0))();
  IntColumn get createdAt => integer().named('createdAt')();
  IntColumn get updatedAt => integer().named('updatedAt')();
  IntColumn get capturedAt => integer().named('capturedAt').nullable()();
  RealColumn get gpsLatitude => real().named('gpsLatitude').nullable()();
  RealColumn get gpsLongitude => real().named('gpsLongitude').nullable()();
  TextColumn get locationName => text().named('locationName').withDefault(const Constant(''))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isCoverPhoto => boolean().named('isCoverPhoto').withDefault(const Constant(false))();
  IntColumn get displayOrder => integer().named('displayOrder').withDefault(const Constant(0))();
  TextColumn get syncStatus =>
      text().named('syncStatus').withDefault(const Constant('LOCAL_ONLY'))();
  TextColumn get futureCloudId => text().named('futureCloudId').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MemoryPhotos extends Table {
  @override
  String get tableName => 'memory_photos';

  TextColumn get memoryId =>
      text().named('memoryId').references(Memories, #id, onDelete: KeyAction.cascade)();
  TextColumn get albumPhotoId =>
      text().named('albumPhotoId').references(AlbumPhotos, #id, onDelete: KeyAction.cascade)();
  IntColumn get displayOrder => integer().named('displayOrder').withDefault(const Constant(0))();
  BoolColumn get isHeroPhoto => boolean().named('isHeroPhoto').withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {memoryId, albumPhotoId};
}

class MemoryAttachments extends Table {
  @override
  String get tableName => 'memory_attachments';

  TextColumn get id => text()();
  TextColumn get memoryId =>
      text().named('memoryId').references(Memories, #id, onDelete: KeyAction.cascade)();
  TextColumn get localUri => text().named('localUri')();
  TextColumn get originalName => text().named('originalName').nullable()();
  TextColumn get mimeType => text().named('mimeType')();
  TextColumn get attachmentType => text().named('attachmentType')();
  IntColumn get createdAt => integer().named('createdAt')();
  TextColumn get syncStatus =>
      text().named('syncStatus').withDefault(const Constant('LOCAL_ONLY'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocationPlaces extends Table {
  @override
  String get tableName => 'location_places';

  TextColumn get id => text()();
  TextColumn get displayName => text().named('displayName')();
  TextColumn get country => text().withDefault(const Constant(''))();
  TextColumn get city => text().withDefault(const Constant(''))();
  TextColumn get region => text().withDefault(const Constant(''))();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get source => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class GeocodingCache extends Table {
  @override
  String get tableName => 'geocoding_cache';

  TextColumn get query => text()();
  TextColumn get displayName => text().named('displayName')();
  TextColumn get country => text().withDefault(const Constant(''))();
  TextColumn get city => text().withDefault(const Constant(''))();
  TextColumn get region => text().withDefault(const Constant(''))();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  IntColumn get cachedAt => integer().named('cachedAt')();

  @override
  Set<Column> get primaryKey => {query};
}

class CloudSyncQueue extends Table {
  @override
  String get tableName => 'cloud_sync_queue';

  TextColumn get id => text()();
  TextColumn get entityType => text().named('entityType')();
  TextColumn get localEntityId => text().named('localEntityId')();
  TextColumn get operation => text()();
  IntColumn get createdAt => integer().named('createdAt')();
  IntColumn get attemptCount => integer().named('attemptCount').withDefault(const Constant(0))();
  TextColumn get lastError => text().named('lastError').nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {entityType, localEntityId, operation},
      ];
}

class EcosystemOutbox extends Table {
  @override
  String get tableName => 'ecosystem_outbox';

  TextColumn get id => text()();
  TextColumn get targetApp => text()();
  TextColumn get envelopeJson => text()();
  TextColumn get idempotencyKey => text()();
  IntColumn get createdAt => integer()();
  IntColumn get deliveredAt => integer().nullable()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {targetApp, idempotencyKey},
      ];
}

class EcosystemInbox extends Table {
  @override
  String get tableName => 'ecosystem_inbox';

  TextColumn get id => text()();
  TextColumn get sourceApp => text()();
  TextColumn get envelopeJson => text()();
  TextColumn get idempotencyKey => text()();
  IntColumn get receivedAt => integer()();
  IntColumn get consumedAt => integer().nullable()();
  TextColumn get disposition =>
      text().withDefault(const Constant('pending'))();
  TextColumn get materializedJourneyId => text().nullable()();
  TextColumn get materializedMemoryId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {sourceApp, idempotencyKey},
      ];
}

class OfflineMapRegions extends Table {
  @override
  String get tableName => 'offline_map_regions';

  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get centerLatitude => real().named('centerLatitude')();
  RealColumn get centerLongitude => real().named('centerLongitude')();
  RealColumn get radiusKm => real().named('radiusKm')();
  IntColumn get zoomMin => integer().named('zoomMin')();
  IntColumn get zoomMax => integer().named('zoomMax')();
  IntColumn get sizeBytes => integer().named('sizeBytes').withDefault(const Constant(0))();
  BoolColumn get isDownloaded => boolean().named('isDownloaded').withDefault(const Constant(false))();
  RealColumn get downloadProgress => real().named('downloadProgress').withDefault(const Constant(0))();
  IntColumn get createdAt => integer().named('createdAt')();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    Trips,
    Memories,
    AlbumPhotos,
    MemoryPhotos,
    MemoryAttachments,
    LocationPlaces,
    GeocodingCache,
    OfflineMapRegions,
    CloudSyncQueue,
    EcosystemOutbox,
    EcosystemInbox,
  ],
)
class WonderlogDatabase extends _$WonderlogDatabase {
  WonderlogDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'wonderlog_flutter'));

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (migrator) => migrator.createAll(),
        onUpgrade: (migrator, from, to) async {
          // Room production baseline is schema v6. A v6 database already
          // contains cloud_sync_queue and memory_attachments, so upgrading
          // v6 -> v7 is intentionally metadata-only.
          if (from < 2) {
            await migrator.createTable(cloudSyncQueue);
          }
          if (from < 8) {
            await migrator.createTable(ecosystemOutbox);
            await migrator.createTable(ecosystemInbox);
          }
          if (from < 9) {
            // E2 introduces true unassigned Memories by making their Journey
            // relationship optional. Existing rows keep their current IDs.
            // Drift 2.31 exposes nullability table rewrites through the
            // experimental TableMigration API. This is the supported way in
            // the pinned dependency to preserve existing rows while changing
            // the Journey foreign key from required to optional.
            // ignore: experimental_member_use
            await migrator.alterTable(TableMigration(memories));

            // Databases created before schema v8 need no addColumn calls here:
            // createTable(ecosystemInbox) above already uses the latest schema.
            if (from >= 8) {
              await migrator.addColumn(
                ecosystemInbox,
                ecosystemInbox.disposition,
              );
              await migrator.addColumn(
                ecosystemInbox,
                ecosystemInbox.materializedJourneyId,
              );
              await migrator.addColumn(
                ecosystemInbox,
                ecosystemInbox.materializedMemoryId,
              );
            }
          }
        },
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
