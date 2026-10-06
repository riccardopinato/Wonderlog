import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:wonderlog/core/database/wonderlog_database.dart';
import 'package:wonderlog/core/ecosystem/drift_ecosystem_transfer_store.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_envelope.dart';
import 'package:wonderlog/core/ecosystem/ecosystem_models.dart';
import 'package:wonderlog/features/memories/data/drift_wonderlog_repository.dart';
import 'package:wonderlog/features/memories/domain/memory_models.dart';

void main() {
  test('v8 fixture migrates to v9 without losing domain relations', () async {
    final directory =
        await Directory.systemTemp.createTemp('wonderlog-v8-v9-fixture-');
    final file = File('${directory.path}/wonderlog.sqlite');

    try {
      final sourceDatabase = WonderlogDatabase(NativeDatabase(file));
      final sourceRepository = DriftWonderlogRepository(sourceDatabase);
      final sourceStore = DriftEcosystemTransferStore(sourceDatabase);

      final journey = await sourceRepository.createJourney(
        title: 'Valle Aurina',
        destination: 'Campo Tures',
        startDate: DateTime(2026, 8, 10),
        endDate: DateTime(2026, 8, 14),
      );
      final now = DateTime.utc(2026, 8, 10, 12);
      final memory = MemoryEntry(
        id: 'legacy-memory',
        journeyId: journey.id,
        title: 'Cascate di Riva',
        journalText: 'Legacy v8 row',
        locationName: 'Campo Tures',
        date: now,
        mood: Mood.nature,
        tags: const ['estate', 'trekking'],
        createdAt: now,
        updatedAt: now,
      );
      await sourceRepository.saveMemory(memory);

      final photo = AlbumPhotoEntry(
        id: 'legacy-photo',
        journeyId: journey.id,
        localUri: 'asset://legacy-photo',
        thumbnailUri: 'asset://legacy-photo',
        originalUri: 'file:///legacy.jpg',
        fileName: 'legacy.jpg',
        mimeType: 'image/jpeg',
        width: 1200,
        height: 800,
        fileSize: 12345,
        createdAt: now,
        updatedAt: now,
      );
      await sourceRepository.savePhoto(photo);
      await sourceRepository.linkPhotoToMemory(
        memoryId: memory.id,
        photoId: photo.id,
        displayOrder: 0,
        isHero: true,
      );
      await sourceRepository.saveAttachment(
        MemoryAttachment(
          id: 'legacy-attachment',
          memoryId: memory.id,
          localUri: 'asset://legacy-document',
          originalName: 'biglietto.pdf',
          mimeType: 'application/pdf',
          attachmentType: 'document',
          createdAt: now,
          syncStatus: 'LOCAL_ONLY',
        ),
      );

      await sourceStore.receiveInbox(
        EcosystemEnvelope(
          sourceApp: EcosystemAppId.annasDiary,
          sourceEntityType: EcosystemEntityType.note,
          sourceEntityId: 'legacy-inbox',
          createdAtUtc: now,
          title: 'Legacy inbox item',
          revision: 1,
        ),
      );
      await sourceDatabase.close();

      final raw = sqlite.sqlite3.open(file.path);
      try {
        raw.execute('PRAGMA foreign_keys = OFF');
        _dropColumn(raw, 'ecosystem_inbox', 'disposition');
        _dropColumn(raw, 'ecosystem_inbox', 'materializedJourneyId');
        _dropColumn(raw, 'ecosystem_inbox', 'materializedMemoryId');
        _makeMemoryJourneyColumnsRequired(raw);
        raw.execute('PRAGMA user_version = 8');
      } finally {
        raw.dispose();
      }

      final migratedDatabase = WonderlogDatabase(NativeDatabase(file));
      final migratedRepository = DriftWonderlogRepository(migratedDatabase);
      final migratedStore = DriftEcosystemTransferStore(migratedDatabase);

      final migratedJourney =
          await migratedRepository.watchJourney(journey.id).first;
      expect(migratedJourney?.title, 'Valle Aurina');

      final migratedMemory =
          await migratedRepository.watchMemory(memory.id).first;
      expect(migratedMemory, isNotNull);
      expect(migratedMemory!.memory.journeyId, journey.id);
      expect(migratedMemory.memory.tags, ['estate', 'trekking']);
      expect(migratedMemory.photos.single.id, photo.id);
      expect(
        migratedMemory.attachments.single.id,
        'legacy-attachment',
      );

      final history = await migratedStore.watchInboxHistory().first;
      expect(history, hasLength(1));
      expect(history.single.isPending, isTrue);
      expect(
        history.single.disposition,
        EcosystemInboxDisposition.pending,
      );
      expect(history.single.materializedJourneyId, isNull);
      expect(history.single.materializedMemoryId, isNull);

      final unassigned = MemoryEntry(
        id: 'post-migration-unassigned',
        journeyId: null,
        title: 'Unassigned after v9',
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

      final foreignKeyViolations =
          await migratedDatabase.customSelect('PRAGMA foreign_key_check').get();
      expect(foreignKeyViolations, isEmpty);

      final versionRow =
          await migratedDatabase.customSelect('PRAGMA user_version').getSingle();
      expect(versionRow.data.values.single, 9);

      await migratedDatabase.close();
    } finally {
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }
    }
  });
}

void _dropColumn(
  sqlite.Database database,
  String table,
  String logicalName,
) {
  final rows = database.select('PRAGMA table_info("$table")');
  final normalized = logicalName.replaceAll('_', '').toLowerCase();
  final actual = rows
      .map((row) => row['name'] as String)
      .where(
        (name) => name.replaceAll('_', '').toLowerCase() == normalized,
      )
      .single;
  database.execute(
    'ALTER TABLE "$table" DROP COLUMN "$actual"',
  );
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
    if (type != null && type.isNotEmpty) {
      buffer.write(' $type');
    }
    if (forceRequired || originalRequired) {
      buffer.write(' NOT NULL');
    }
    if (defaultValue != null) {
      buffer.write(' DEFAULT $defaultValue');
    }
    if (primaryKey) {
      buffer.write(' PRIMARY KEY');
    }
    return buffer.toString();
  }).join(', ');

  final quotedColumns =
      columnNames.map((name) => '"$name"').join(', ');

  database.execute(
    'CREATE TABLE "memories_v8_fixture" ($definitions)',
  );
  database.execute(
    'INSERT INTO "memories_v8_fixture" ($quotedColumns) '
    'SELECT $quotedColumns FROM "memories"',
  );
  database.execute('DROP TABLE "memories"');
  database.execute(
    'ALTER TABLE "memories_v8_fixture" RENAME TO "memories"',
  );
}
