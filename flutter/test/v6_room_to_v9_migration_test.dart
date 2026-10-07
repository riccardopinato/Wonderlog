import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:wonderlog/core/database/legacy_room_schema_normalizer.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart'
    hide MemoryAttachment;
import 'package:wonderlog/features/memories/data/drift_wonderlog_repository.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';

const _roomV6Tables = <String>[
  'trips',
  'memories',
  'album_photos',
  'memory_photos',
  'location_places',
  'geocoding_cache',
  'offline_map_regions',
  'cloud_sync_queue',
  'memory_attachments',
];

void main() {
  test('canonical Room v6 donor schema migrates to Drift v9 without data loss',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('wonderlog-room-v6-v9-');
    final file = File(
      '${directory.path}${Platform.pathSeparator}wanderlog-memories-db',
    );

    try {
      final raw = sqlite.sqlite3.open(file.path);
      try {
        _createCanonicalRoomV6(raw);
        expect(_userVersion(raw), 6);
        expect(_tableNames(raw).containsAll(_roomV6Tables), isTrue);
        for (final table in _roomV6Tables) {
          expect(_rowCount(raw, table), 1, reason: 'Room v6 table $table');
        }
      } finally {
        raw.dispose();
      }

      const normalizer = LegacyRoomSchemaNormalizer();
      normalizer.normalize(file);
      // A crash between normalization and Drift open must be retry-safe.
      normalizer.normalize(file);

      final normalized = sqlite.sqlite3.open(file.path);
      try {
        expect(_userVersion(normalized), 6);
        final tripColumns = _columnNames(normalized, 'trips');
        expect(tripColumns, contains('destination_name'));
        expect(tripColumns, isNot(contains('destinationName')));
        final memoryColumns = _columnNames(normalized, 'memories');
        expect(memoryColumns, contains('trip_id'));
        expect(memoryColumns, isNot(contains('tripId')));
        expect(normalized.select('PRAGMA foreign_key_check'), isEmpty);
      } finally {
        normalized.dispose();
      }

      final migrated = WonderlogDatabase(NativeDatabase(file));
      final repository = DriftWonderlogRepository(migrated);

      final version =
          await migrated.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, 9);

      final journey = await repository.watchJourney('room-v6-trip').first;
      expect(journey, isNotNull);
      expect(journey!.destination, 'Torino');
      expect(journey.country, 'Italia');

      final restored =
          await repository.watchMemory('room-v6-memory').first;
      expect(restored, isNotNull);
      expect(restored!.memory.journeyId, 'room-v6-trip');
      expect(restored.memory.tags, ['torino', 'viaggio']);
      expect(restored.photos.single.id, 'room-v6-photo');
      expect(restored.attachments.single.id, 'room-v6-attachment');

      final foreignKeys =
          await migrated.customSelect('PRAGMA foreign_key_check').get();
      expect(foreignKeys, isEmpty);

      final unassigned = MemoryEntry(
        id: 'after-v9-unassigned',
        journeyId: null,
        title: 'After migration',
        journalText: '',
        locationName: '',
        date: DateTime.utc(2026, 10, 7),
        mood: Mood.calm,
        tags: const [],
        createdAt: DateTime.utc(2026, 10, 7),
        updatedAt: DateTime.utc(2026, 10, 7),
      );
      await repository.saveMemory(unassigned);
      expect(
        (await repository.watchAllMemories().first)
            .singleWhere((item) => item.id == unassigned.id)
            .journeyId,
        isNull,
      );

      for (final table in _roomV6Tables) {
        final count = await migrated
            .customSelect('SELECT COUNT(*) AS c FROM "$table"')
            .getSingle();
        expect(
          count.read<int>('c'),
          table == 'memories' ? 2 : 1,
          reason: 'migrated table $table',
        );
      }

      await migrated.close();
    } finally {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });
}

void _createCanonicalRoomV6(sqlite.Database db) {
  db.execute('PRAGMA foreign_keys = ON');

  db.execute('''
    CREATE TABLE trips (
      id TEXT NOT NULL PRIMARY KEY,
      destinationName TEXT NOT NULL,
      country TEXT NOT NULL,
      startDate TEXT NOT NULL,
      endDate TEXT NOT NULL,
      coverImage TEXT NOT NULL,
      description TEXT NOT NULL,
      accentGradientIndex INTEGER NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      title TEXT NOT NULL,
      destination TEXT NOT NULL,
      coverPhotoId TEXT NOT NULL,
      accentTheme TEXT NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      favorite INTEGER NOT NULL,
      archived INTEGER NOT NULL,
      statistics TEXT NOT NULL,
      futureCloudId TEXT,
      syncStatus TEXT NOT NULL
    )
  ''');

  db.execute('''
    CREATE TABLE memories (
      id TEXT NOT NULL PRIMARY KEY,
      tripId TEXT NOT NULL,
      journeyId TEXT NOT NULL,
      title TEXT NOT NULL,
      note TEXT NOT NULL,
      journalText TEXT NOT NULL,
      image TEXT NOT NULL,
      locationName TEXT NOT NULL,
      latitude REAL,
      longitude REAL,
      date TEXT NOT NULL,
      mood TEXT NOT NULL,
      tags TEXT NOT NULL,
      favorite INTEGER NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      displayOrder INTEGER NOT NULL,
      syncStatus TEXT NOT NULL,
      futureCloudId TEXT,
      FOREIGN KEY (tripId) REFERENCES trips(id)
        ON UPDATE NO ACTION ON DELETE CASCADE
    )
  ''');
  db.execute('CREATE INDEX index_memories_tripId ON memories(tripId)');

  db.execute('''
    CREATE TABLE album_photos (
      id TEXT NOT NULL PRIMARY KEY,
      journeyId TEXT NOT NULL,
      localUri TEXT NOT NULL,
      thumbnailUri TEXT NOT NULL,
      originalUri TEXT NOT NULL,
      fileName TEXT NOT NULL,
      mimeType TEXT NOT NULL,
      width INTEGER NOT NULL,
      height INTEGER NOT NULL,
      fileSize INTEGER NOT NULL,
      createdAt INTEGER NOT NULL,
      updatedAt INTEGER NOT NULL,
      capturedAt INTEGER,
      gpsLatitude REAL,
      gpsLongitude REAL,
      locationName TEXT NOT NULL,
      favorite INTEGER NOT NULL,
      isCoverPhoto INTEGER NOT NULL,
      displayOrder INTEGER NOT NULL,
      syncStatus TEXT NOT NULL,
      futureCloudId TEXT,
      FOREIGN KEY (journeyId) REFERENCES trips(id)
        ON UPDATE NO ACTION ON DELETE CASCADE
    )
  ''');
  db.execute(
    'CREATE INDEX index_album_photos_journeyId '
    'ON album_photos(journeyId)',
  );

  db.execute('''
    CREATE TABLE memory_photos (
      memoryId TEXT NOT NULL,
      albumPhotoId TEXT NOT NULL,
      displayOrder INTEGER NOT NULL,
      isHeroPhoto INTEGER NOT NULL,
      PRIMARY KEY (memoryId, albumPhotoId),
      FOREIGN KEY (memoryId) REFERENCES memories(id)
        ON UPDATE NO ACTION ON DELETE CASCADE,
      FOREIGN KEY (albumPhotoId) REFERENCES album_photos(id)
        ON UPDATE NO ACTION ON DELETE CASCADE
    )
  ''');
  db.execute(
    'CREATE INDEX index_memory_photos_memoryId '
    'ON memory_photos(memoryId)',
  );
  db.execute(
    'CREATE INDEX index_memory_photos_albumPhotoId '
    'ON memory_photos(albumPhotoId)',
  );

  db.execute('''
    CREATE TABLE location_places (
      id TEXT NOT NULL PRIMARY KEY,
      displayName TEXT NOT NULL,
      country TEXT NOT NULL,
      city TEXT NOT NULL,
      region TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      source TEXT NOT NULL
    )
  ''');

  db.execute('''
    CREATE TABLE geocoding_cache (
      query TEXT NOT NULL PRIMARY KEY,
      displayName TEXT NOT NULL,
      country TEXT NOT NULL,
      city TEXT NOT NULL,
      region TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      cachedAt INTEGER NOT NULL
    )
  ''');

  db.execute('''
    CREATE TABLE offline_map_regions (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      centerLatitude REAL NOT NULL,
      centerLongitude REAL NOT NULL,
      radiusKm REAL NOT NULL,
      zoomMin INTEGER NOT NULL,
      zoomMax INTEGER NOT NULL,
      sizeBytes INTEGER NOT NULL,
      isDownloaded INTEGER NOT NULL,
      downloadProgress REAL NOT NULL,
      createdAt INTEGER NOT NULL
    )
  ''');

  db.execute('''
    CREATE TABLE cloud_sync_queue (
      id TEXT NOT NULL PRIMARY KEY,
      entityType TEXT NOT NULL,
      localEntityId TEXT NOT NULL,
      operation TEXT NOT NULL,
      createdAt INTEGER NOT NULL,
      attemptCount INTEGER NOT NULL,
      lastError TEXT
    )
  ''');
  db.execute(
    'CREATE UNIQUE INDEX index_cloud_sync_queue_entityType_localEntityId_operation '
    'ON cloud_sync_queue(entityType, localEntityId, operation)',
  );

  db.execute('''
    CREATE TABLE memory_attachments (
      id TEXT NOT NULL PRIMARY KEY,
      memoryId TEXT NOT NULL,
      localUri TEXT NOT NULL,
      originalName TEXT,
      mimeType TEXT NOT NULL,
      attachmentType TEXT NOT NULL,
      createdAt INTEGER NOT NULL,
      syncStatus TEXT NOT NULL,
      FOREIGN KEY (memoryId) REFERENCES memories(id)
        ON UPDATE NO ACTION ON DELETE CASCADE
    )
  ''');
  db.execute(
    'CREATE INDEX index_memory_attachments_memoryId '
    'ON memory_attachments(memoryId)',
  );

  db.execute('''
    INSERT INTO trips (
      id, destinationName, country, startDate, endDate, coverImage,
      description, accentGradientIndex, latitude, longitude, title,
      destination, coverPhotoId, accentTheme, createdAt, updatedAt,
      favorite, archived, statistics, futureCloudId, syncStatus
    ) VALUES (
      'room-v6-trip', 'Torino', 'Italia', '2026-10-16', '2026-10-18', '',
      'Legacy Room v6 journey', 0, 45.0703, 7.6869, 'Torino',
      'Torino', '', 'Preset_0', 1792144800000, 1792144800000,
      1, 0, '', NULL, 'LOCAL_ONLY'
    )
  ''');

  db.execute('''
    INSERT INTO memories (
      id, tripId, journeyId, title, note, journalText, image, locationName,
      latitude, longitude, date, mood, tags, favorite, createdAt, updatedAt,
      displayOrder, syncStatus, futureCloudId
    ) VALUES (
      'room-v6-memory', 'room-v6-trip', 'room-v6-trip', 'Mole Antonelliana',
      'Legacy note', 'Legacy Room data', '', 'Torino', 45.0690, 7.6930,
      '2026-10-16', 'HAPPY', 'torino||viaggio', 1, 1792148400000,
      1792148400000, 0, 'LOCAL_ONLY', NULL
    )
  ''');

  db.execute('''
    INSERT INTO album_photos (
      id, journeyId, localUri, thumbnailUri, originalUri, fileName, mimeType,
      width, height, fileSize, createdAt, updatedAt, capturedAt, gpsLatitude,
      gpsLongitude, locationName, favorite, isCoverPhoto, displayOrder,
      syncStatus, futureCloudId
    ) VALUES (
      'room-v6-photo', 'room-v6-trip', 'file:///legacy/photo.jpg',
      'file:///legacy/thumb.jpg', 'file:///legacy/photo.jpg', 'photo.jpg',
      'image/jpeg', 1600, 1200, 123456, 1792148400000, 1792148400000,
      1792148400000, 45.0690, 7.6930, 'Torino', 1, 1, 0,
      'LOCAL_ONLY', NULL
    )
  ''');

  db.execute('''
    INSERT INTO memory_photos (
      memoryId, albumPhotoId, displayOrder, isHeroPhoto
    ) VALUES ('room-v6-memory', 'room-v6-photo', 0, 1)
  ''');

  db.execute('''
    INSERT INTO location_places (
      id, displayName, country, city, region, latitude, longitude, source
    ) VALUES (
      'room-v6-place', 'Torino, Italia', 'Italia', 'Torino', 'Piemonte',
      45.0703, 7.6869, 'NOMINATIM'
    )
  ''');

  db.execute('''
    INSERT INTO geocoding_cache (
      query, displayName, country, city, region, latitude, longitude, cachedAt
    ) VALUES (
      'torino', 'Torino, Italia', 'Italia', 'Torino', 'Piemonte',
      45.0703, 7.6869, 1792144800000
    )
  ''');

  db.execute('''
    INSERT INTO offline_map_regions (
      id, name, centerLatitude, centerLongitude, radiusKm, zoomMin, zoomMax,
      sizeBytes, isDownloaded, downloadProgress, createdAt
    ) VALUES (
      'room-v6-region', 'Torino', 45.0703, 7.6869, 5.0, 8, 15,
      1024, 1, 1.0, 1792144800000
    )
  ''');

  db.execute('''
    INSERT INTO cloud_sync_queue (
      id, entityType, localEntityId, operation, createdAt, attemptCount,
      lastError
    ) VALUES (
      'room-v6-queue', 'JOURNEY', 'room-v6-trip', 'UPDATE',
      1792144800000, 1, NULL
    )
  ''');

  db.execute('''
    INSERT INTO memory_attachments (
      id, memoryId, localUri, originalName, mimeType, attachmentType,
      createdAt, syncStatus
    ) VALUES (
      'room-v6-attachment', 'room-v6-memory', 'file:///legacy/ticket.pdf',
      'ticket.pdf', 'application/pdf', 'document', 1792144800000,
      'LOCAL_ONLY'
    )
  ''');

  db.execute('PRAGMA user_version = 6');
}

Set<String> _tableNames(sqlite.Database db) => db
    .select(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
    )
    .map((row) => row['name'] as String)
    .toSet();

int _rowCount(sqlite.Database db, String table) =>
    db.select('SELECT COUNT(*) AS c FROM "$table"').single['c'] as int;

int _userVersion(sqlite.Database db) =>
    db.select('PRAGMA user_version').single.values.single as int;

Set<String> _columnNames(sqlite.Database db, String table) => db
    .select('PRAGMA table_info("$table")')
    .map((row) => row['name'] as String)
    .toSet();
