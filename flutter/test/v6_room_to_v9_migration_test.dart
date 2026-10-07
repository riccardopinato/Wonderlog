import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:wonderlog/core/database/wonderlog_database.dart' hide MemoryAttachment;
import 'package:wonderlog/features/memories/data/drift_wonderlog_repository.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';

void main() {
  test('Room v6-shaped fixture migrates to Drift v9 without data loss',
      () async {
    final directory =
        await Directory.systemTemp.createTemp('wonderlog-room-v6-v9-');
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'wanderlog-memories-db',
    );

    try {
      final source = WonderlogDatabase(NativeDatabase(file));
      final repository = DriftWonderlogRepository(source);
      final journey = await repository.createJourney(
        title: 'Legacy Journey',
        destination: 'Torino',
        startDate: DateTime(2025, 10, 16),
        endDate: DateTime(2025, 10, 18),
      );
      final now = DateTime.utc(2025, 10, 16, 12);
      final memory = MemoryEntry(
        id: 'room-v6-memory',
        journeyId: journey.id,
        title: 'Mole Antonelliana',
        journalText: 'Legacy Room data',
        locationName: 'Torino',
        date: now,
        mood: Mood.happy,
        tags: const ['torino', 'viaggio'],
        createdAt: now,
        updatedAt: now,
      );
      await repository.saveMemory(memory);
      final photo = AlbumPhotoEntry(
        id: 'room-v6-photo',
        journeyId: journey.id,
        localUri: 'file:///legacy/photo.jpg',
        thumbnailUri: 'file:///legacy/thumb.jpg',
        originalUri: 'file:///legacy/photo.jpg',
        fileName: 'photo.jpg',
        mimeType: 'image/jpeg',
        width: 1600,
        height: 1200,
        fileSize: 123456,
        createdAt: now,
        updatedAt: now,
      );
      await repository.savePhoto(photo);
      await repository.linkPhotoToMemory(
        memoryId: memory.id,
        photoId: photo.id,
        displayOrder: 0,
        isHero: true,
      );
      await repository.saveAttachment(
        MemoryAttachment(
          id: 'room-v6-attachment',
          memoryId: memory.id,
          localUri: 'file:///legacy/ticket.pdf',
          originalName: 'ticket.pdf',
          mimeType: 'application/pdf',
          attachmentType: 'document',
          createdAt: now,
          syncStatus: 'LOCAL_ONLY',
        ),
      );
      await source.close();

      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('PRAGMA foreign_keys = OFF');
        raw.execute('DROP TABLE IF EXISTS ecosystem_outbox');
        raw.execute('DROP TABLE IF EXISTS ecosystem_inbox');
        _makeMemoryJourneyColumnsRequired(raw);
        raw.execute(
          "UPDATE memories SET tags = 'torino||viaggio' "
          "WHERE id = 'room-v6-memory'",
        );
        raw.execute('PRAGMA user_version = 6');
      } finally {
        raw.dispose();
      }

      final migrated = WonderlogDatabase(NativeDatabase(file));
      final migratedRepository = DriftWonderlogRepository(migrated);

      final version =
          await migrated.customSelect('PRAGMA user_version').getSingle();
      expect(version.data.values.single, 9);

      final restoredJourney =
          await migratedRepository.watchJourney(journey.id).first;
      expect(restoredJourney?.title, 'Legacy Journey');

      final restored =
          await migratedRepository.watchMemory('room-v6-memory').first;
      expect(restored, isNotNull);
      expect(restored!.memory.journeyId, journey.id);
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
        date: now,
        mood: Mood.calm,
        tags: const [],
        createdAt: now,
        updatedAt: now,
      );
      await migratedRepository.saveMemory(unassigned);
      expect(
        (await migratedRepository.watchAllMemories().first)
            .singleWhere((item) => item.id == unassigned.id)
            .journeyId,
        isNull,
      );

      await migrated.close();
    } finally {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });
}

void _makeMemoryJourneyColumnsRequired(sqlite.Database database) {
  final rows = database.select('PRAGMA table_info("memories")').toList();
  final columnNames =
      rows.map((row) => row['name'] as String).toList(growable: false);

  final definitions = rows.map((row) {
    final name = row['name'] as String;
    final type = (row['type'] as String?)?.trim();
    final normalized = name.replaceAll('_', '').toLowerCase();
    final forceRequired =
        normalized == 'tripid' || normalized == 'journeyid';
    final originalRequired = (row['notnull'] as int? ?? 0) == 1;
    final primaryKey = (row['pk'] as int? ?? 0) > 0;
    final defaultValue = row['dflt_value'];

    final buffer = StringBuffer('"$name"');
    if (type != null && type.isNotEmpty) buffer.write(' $type');
    if (forceRequired || originalRequired) buffer.write(' NOT NULL');
    if (defaultValue != null) buffer.write(' DEFAULT $defaultValue');
    if (primaryKey) buffer.write(' PRIMARY KEY');
    return buffer.toString();
  }).join(', ');

  final quotedColumns =
      columnNames.map((name) => '"$name"').join(', ');

  database.execute(
    'CREATE TABLE "memories_room_v6_fixture" ($definitions)',
  );
  database.execute(
    'INSERT INTO "memories_room_v6_fixture" ($quotedColumns) '
    'SELECT $quotedColumns FROM "memories"',
  );
  database.execute('DROP TABLE "memories"');
  database.execute(
    'ALTER TABLE "memories_room_v6_fixture" RENAME TO "memories"',
  );
}
