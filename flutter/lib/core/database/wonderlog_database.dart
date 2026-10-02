import 'package:drift/drift.dart';

import 'database_connection.dart';

part 'wonderlog_database.g.dart';

class Trips extends Table {
  @override
  String get tableName => 'trips';

  TextColumn get id => text()();
  TextColumn get destinationName => text()();
  TextColumn get country => text().withDefault(const Constant(''))();
  TextColumn get startDate => text()();
  TextColumn get endDate => text()();
  TextColumn get coverImage => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  IntColumn get accentGradientIndex => integer().withDefault(const Constant(0))();
  RealColumn get latitude => real().withDefault(const Constant(0))();
  RealColumn get longitude => real().withDefault(const Constant(0))();
  TextColumn get title => text()();
  TextColumn get destination => text()();
  TextColumn get coverPhotoId => text().withDefault(const Constant(''))();
  TextColumn get accentTheme =>
      text().withDefault(const Constant('Preset_0'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();
  TextColumn get statistics => text().withDefault(const Constant(''))();
  TextColumn get futureCloudId => text().nullable()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('LOCAL_ONLY'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Memories extends Table {
  @override
  String get tableName => 'memories';

  TextColumn get id => text()();
  TextColumn get tripId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get journeyId => text()();
  TextColumn get title => text()();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get journalText => text().withDefault(const Constant(''))();
  TextColumn get image => text().withDefault(const Constant(''))();
  TextColumn get locationName => text().withDefault(const Constant(''))();
  RealColumn get latitude => real().nullable()();
  RealColumn get longitude => real().nullable()();
  TextColumn get date => text()();
  TextColumn get mood => text().withDefault(const Constant('HAPPY'))();
  TextColumn get tagsJson =>
      text().named('tags').withDefault(const Constant('[]'))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('LOCAL_ONLY'))();
  TextColumn get futureCloudId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class AlbumPhotos extends Table {
  @override
  String get tableName => 'album_photos';

  TextColumn get id => text()();
  TextColumn get journeyId =>
      text().references(Trips, #id, onDelete: KeyAction.cascade)();
  TextColumn get localUri => text()();
  TextColumn get thumbnailUri => text().withDefault(const Constant(''))();
  TextColumn get originalUri => text().withDefault(const Constant(''))();
  TextColumn get fileName => text().withDefault(const Constant(''))();
  TextColumn get mimeType => text().withDefault(const Constant('image/jpeg'))();
  IntColumn get width => integer().withDefault(const Constant(0))();
  IntColumn get height => integer().withDefault(const Constant(0))();
  IntColumn get fileSize => integer().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get capturedAt => integer().nullable()();
  RealColumn get gpsLatitude => real().nullable()();
  RealColumn get gpsLongitude => real().nullable()();
  TextColumn get locationName => text().withDefault(const Constant(''))();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  BoolColumn get isCoverPhoto => boolean().withDefault(const Constant(false))();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('LOCAL_ONLY'))();
  TextColumn get futureCloudId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class MemoryPhotos extends Table {
  @override
  String get tableName => 'memory_photos';

  TextColumn get memoryId =>
      text().references(Memories, #id, onDelete: KeyAction.cascade)();
  TextColumn get albumPhotoId =>
      text().references(AlbumPhotos, #id, onDelete: KeyAction.cascade)();
  IntColumn get displayOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isHeroPhoto => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {memoryId, albumPhotoId};
}

class MemoryAttachments extends Table {
  @override
  String get tableName => 'memory_attachments';

  TextColumn get id => text()();
  TextColumn get memoryId =>
      text().references(Memories, #id, onDelete: KeyAction.cascade)();
  TextColumn get localUri => text()();
  TextColumn get originalName => text().nullable()();
  TextColumn get mimeType => text()();
  TextColumn get attachmentType => text()();
  IntColumn get createdAt => integer()();
  TextColumn get syncStatus =>
      text().withDefault(const Constant('LOCAL_ONLY'))();

  @override
  Set<Column> get primaryKey => {id};
}

class LocationPlaces extends Table {
  @override
  String get tableName => 'location_places';

  TextColumn get id => text()();
  TextColumn get displayName => text()();
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
  TextColumn get displayName => text()();
  TextColumn get country => text().withDefault(const Constant(''))();
  TextColumn get city => text().withDefault(const Constant(''))();
  TextColumn get region => text().withDefault(const Constant(''))();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  IntColumn get cachedAt => integer()();

  @override
  Set<Column> get primaryKey => {query};
}

class CloudSyncQueue extends Table {
  @override
  String get tableName => 'cloud_sync_queue';

  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get localEntityId => text()();
  TextColumn get operation => text()();
  IntColumn get createdAt => integer()();
  IntColumn get attemptCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {entityType, localEntityId, operation},
      ];
}

class OfflineMapRegions extends Table {
  @override
  String get tableName => 'offline_map_regions';

  TextColumn get id => text()();
  TextColumn get name => text()();
  RealColumn get centerLatitude => real()();
  RealColumn get centerLongitude => real()();
  RealColumn get radiusKm => real()();
  IntColumn get zoomMin => integer()();
  IntColumn get zoomMax => integer()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  BoolColumn get isDownloaded => boolean().withDefault(const Constant(false))();
  RealColumn get downloadProgress => real().withDefault(const Constant(0))();
  IntColumn get createdAt => integer()();

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
  ],
)
class WonderlogDatabase extends _$WonderlogDatabase {
  WonderlogDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'wonderlog_flutter'));

  @override
  int get schemaVersion => 7;

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
        },
        beforeOpen: (_) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
