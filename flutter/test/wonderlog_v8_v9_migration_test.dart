import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/core/ecosystem/drift_ecosystem_transfer_store.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_codec.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_transfer_store.dart';
import 'package:wonderlog/features/memories/data/drift_wonderlog_repository.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';

void main() {
  test('v8 -> v9 preserves Memory relations and enables unassigned Memories',
      () async {
    final directory = await Directory.systemTemp.createTemp('wonderlog_v8_v9_');
    final file = File('${directory.path}/wonderlog.db');

    try {
      final envelope = EcosystemEnvelope(
        sourceApp: EcosystemAppId.annasDiary,
        sourceEntityType: EcosystemEntityType.note,
        sourceEntityId: 'legacy-note',
        createdAtUtc: DateTime.utc(2026, 10, 5),
        title: 'Legacy inbox item',
        revision: 1,
      );
      _createV8Fixture(
        file,
        envelopeJson: EcosystemCodec.encode(envelope),
        idempotencyKey: envelope.idempotencyKey,
      );

      final database = WonderlogDatabase(NativeDatabase(file));
      try {
        // First query opens the database and executes the v8 -> v9 migration.
        await database.customSelect('SELECT 1').getSingle();

        final userVersion =
            await database.customSelect('PRAGMA user_version').getSingle();
        expect(userVersion.read<int>('user_version'), 9);

        final repository = DriftWonderlogRepository(database);
        final memories = await repository.watchAllMemories().first;
        expect(memories, hasLength(1));
        expect(memories.single.id, 'memory-1');
        expect(memories.single.journeyId, 'journey-1');
        expect(memories.single.title, 'Legacy memory');

        final links = await database.select(database.memoryPhotos).get();
        expect(links, hasLength(1));
        expect(links.single.memoryId, 'memory-1');
        expect(links.single.albumPhotoId, 'photo-1');

        final attachments =
            await database.select(database.memoryAttachments).get();
        expect(attachments, hasLength(1));
        expect(attachments.single.memoryId, 'memory-1');
        expect(attachments.single.id, 'attachment-1');

        final photos = await database.select(database.albumPhotos).get();
        expect(photos, hasLength(1));
        expect(photos.single.id, 'photo-1');

        final store = DriftEcosystemTransferStore(database);
        final inbox = await store.watchInboxHistory().first;
        expect(inbox, hasLength(1));
        expect(inbox.single.disposition, EcosystemInboxDisposition.pending);
        expect(inbox.single.materializedJourneyId, isNull);
        expect(inbox.single.materializedMemoryId, isNull);

        final tableInfo =
            await database.customSelect("PRAGMA table_info('memories')").get();
        final trip = tableInfo.singleWhere(
          (row) => row.read<String>('name') == 'trip_id',
        );
        final journey = tableInfo.singleWhere(
          (row) => row.read<String>('name') == 'journey_id',
        );
        expect(trip.read<int>('notnull'), 0);
        expect(journey.read<int>('notnull'), 0);

        final now = DateTime.utc(2026, 10, 6);
        await repository.saveMemory(
          MemoryEntry(
            id: 'free-memory',
            journeyId: null,
            title: 'Unassigned after migration',
            journalText: '',
            locationName: '',
            date: now,
            mood: Mood.calm,
            tags: const ['ecosystem'],
            createdAt: now,
            updatedAt: now,
          ),
        );

        expect(await repository.countUnassignedMemories(), 1);
      } finally {
        await database.close();
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}

void _createV8Fixture(
  File file, {
  required String envelopeJson,
  required String idempotencyKey,
}) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    db.execute('PRAGMA foreign_keys = OFF');

    db.execute('''
      CREATE TABLE trips (
        id TEXT NOT NULL PRIMARY KEY,
        destination_name TEXT NOT NULL,
        country TEXT NOT NULL DEFAULT '',
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        cover_image TEXT NOT NULL DEFAULT '',
        description TEXT NOT NULL DEFAULT '',
        accent_gradient_index INTEGER NOT NULL DEFAULT 0,
        latitude REAL NOT NULL DEFAULT 0,
        longitude REAL NOT NULL DEFAULT 0,
        title TEXT NOT NULL,
        destination TEXT NOT NULL,
        cover_photo_id TEXT NOT NULL DEFAULT '',
        accent_theme TEXT NOT NULL DEFAULT 'Preset_0',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        favorite INTEGER NOT NULL DEFAULT 0,
        archived INTEGER NOT NULL DEFAULT 0,
        statistics TEXT NOT NULL DEFAULT '',
        future_cloud_id TEXT,
        sync_status TEXT NOT NULL DEFAULT 'LOCAL_ONLY'
      )
    ''');

    db.execute('''
      CREATE TABLE memories (
        id TEXT NOT NULL PRIMARY KEY,
        trip_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
        journey_id TEXT NOT NULL,
        title TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        journal_text TEXT NOT NULL DEFAULT '',
        image TEXT NOT NULL DEFAULT '',
        location_name TEXT NOT NULL DEFAULT '',
        latitude REAL,
        longitude REAL,
        date TEXT NOT NULL,
        mood TEXT NOT NULL DEFAULT 'HAPPY',
        tags TEXT NOT NULL DEFAULT '[]',
        favorite INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        display_order INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'LOCAL_ONLY',
        future_cloud_id TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE album_photos (
        id TEXT NOT NULL PRIMARY KEY,
        journey_id TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
        local_uri TEXT NOT NULL,
        thumbnail_uri TEXT NOT NULL DEFAULT '',
        original_uri TEXT NOT NULL DEFAULT '',
        file_name TEXT NOT NULL DEFAULT '',
        mime_type TEXT NOT NULL DEFAULT 'image/jpeg',
        width INTEGER NOT NULL DEFAULT 0,
        height INTEGER NOT NULL DEFAULT 0,
        file_size INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        captured_at INTEGER,
        gps_latitude REAL,
        gps_longitude REAL,
        location_name TEXT NOT NULL DEFAULT '',
        favorite INTEGER NOT NULL DEFAULT 0,
        is_cover_photo INTEGER NOT NULL DEFAULT 0,
        display_order INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'LOCAL_ONLY',
        future_cloud_id TEXT
      )
    ''');

    db.execute('''
      CREATE TABLE memory_photos (
        memory_id TEXT NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
        album_photo_id TEXT NOT NULL REFERENCES album_photos(id) ON DELETE CASCADE,
        display_order INTEGER NOT NULL DEFAULT 0,
        is_hero_photo INTEGER NOT NULL DEFAULT 0,
        PRIMARY KEY (memory_id, album_photo_id)
      )
    ''');

    db.execute('''
      CREATE TABLE memory_attachments (
        id TEXT NOT NULL PRIMARY KEY,
        memory_id TEXT NOT NULL REFERENCES memories(id) ON DELETE CASCADE,
        local_uri TEXT NOT NULL,
        original_name TEXT,
        mime_type TEXT NOT NULL,
        attachment_type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        sync_status TEXT NOT NULL DEFAULT 'LOCAL_ONLY'
      )
    ''');

    db.execute('''
      CREATE TABLE ecosystem_inbox (
        id TEXT NOT NULL PRIMARY KEY,
        source_app TEXT NOT NULL,
        envelope_json TEXT NOT NULL,
        idempotency_key TEXT NOT NULL,
        received_at INTEGER NOT NULL,
        consumed_at INTEGER,
        UNIQUE (source_app, idempotency_key)
      )
    ''');

    db.execute(
      'INSERT INTO trips (id, destination_name, start_date, end_date, title, '
      'destination, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        'journey-1',
        'Valle Aurina',
        '2026-08-10',
        '2026-08-14',
        'Valle Aurina',
        'Campo Tures',
        1770000000000,
        1770000000000,
      ],
    );

    db.execute(
      'INSERT INTO memories (id, trip_id, journey_id, title, journal_text, '
      'date, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
      [
        'memory-1',
        'journey-1',
        'journey-1',
        'Legacy memory',
        'Preserve me',
        '2026-08-11',
        1770000000001,
        1770000000001,
      ],
    );

    db.execute(
      'INSERT INTO album_photos (id, journey_id, local_uri, file_name, '
      'created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?)',
      [
        'photo-1',
        'journey-1',
        'media://photo-1',
        'photo.jpg',
        1770000000002,
        1770000000002,
      ],
    );

    db.execute(
      'INSERT INTO memory_photos '
      '(memory_id, album_photo_id, display_order, is_hero_photo) '
      'VALUES (?, ?, ?, ?)',
      ['memory-1', 'photo-1', 0, 1],
    );

    db.execute(
      'INSERT INTO memory_attachments '
      '(id, memory_id, local_uri, mime_type, attachment_type, created_at) '
      'VALUES (?, ?, ?, ?, ?, ?)',
      [
        'attachment-1',
        'memory-1',
        'media://doc-1',
        'application/pdf',
        'document',
        1770000000003,
      ],
    );

    db.execute(
      'INSERT INTO ecosystem_inbox '
      '(id, source_app, envelope_json, idempotency_key, received_at) '
      'VALUES (?, ?, ?, ?, ?)',
      [
        'inbox-1',
        EcosystemAppId.annasDiary.wireValue,
        envelopeJson,
        idempotencyKey,
        1770000000004,
      ],
    );

    db.execute('PRAGMA user_version = 8');
  } finally {
    db.dispose();
  }
}
