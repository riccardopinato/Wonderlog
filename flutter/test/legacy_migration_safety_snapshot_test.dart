import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wonderlog/core/database/legacy_migration_safety_snapshot.dart';

void main() {
  test('legacy migration snapshot copies and hashes DB plus sidecars',
      () async {
    final root = await Directory.systemTemp.createTemp(
      'wonderlog-room-snapshot-',
    );
    try {
      final database = File(
        '${root.path}${Platform.pathSeparator}wanderlog-memories-db',
      );
      final wal = File(database.path + '-wal');
      final shm = File(database.path + '-shm');
      await database.writeAsBytes(utf8.encode('room-db-v6'));
      await wal.writeAsBytes([1, 2, 3, 4]);
      await shm.writeAsBytes([5, 6, 7]);

      final backupRoot = Directory(
        '${root.path}${Platform.pathSeparator}backups',
      );
      final snapshot = await const LegacyMigrationSafetySnapshot().ensure(
        databaseFile: database,
        backupRoot: backupRoot,
      );

      final files = (snapshot.manifest['files']! as List)
          .cast<Map<String, Object?>>();
      expect(
        files.map((entry) => entry['name']).toSet(),
        {
          'wanderlog-memories-db',
          'wanderlog-memories-db-wal',
          'wanderlog-memories-db-shm',
        },
      );
      expect(snapshot.manifest['targetSchemaVersion'], 9);

      for (final source in [database, wal, shm]) {
        final sourceName = source.path.split(Platform.pathSeparator).last;
        final copied = File(
          '${snapshot.directory.path}'
          '${Platform.pathSeparator}$sourceName',
        );
        expect(await copied.exists(), isTrue);
        expect(
          sha256.convert(await copied.readAsBytes()),
          sha256.convert(await source.readAsBytes()),
        );
      }
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('same immutable source reuses the verified snapshot', () async {
    final root = await Directory.systemTemp.createTemp(
      'wonderlog-room-snapshot-repeat-',
    );
    try {
      final database = File(
        '${root.path}${Platform.pathSeparator}wanderlog-memories-db',
      );
      await database.writeAsBytes(utf8.encode('same-room-db'));
      final backupRoot = Directory(
        '${root.path}${Platform.pathSeparator}backups',
      );
      const service = LegacyMigrationSafetySnapshot();

      final first = await service.ensure(
        databaseFile: database,
        backupRoot: backupRoot,
      );
      final second = await service.ensure(
        databaseFile: database,
        backupRoot: backupRoot,
      );

      expect(second.directory.path, first.directory.path);
      expect(
        second.manifest['sourceFingerprint'],
        first.manifest['sourceFingerprint'],
      );
    } finally {
      await root.delete(recursive: true);
    }
  });

  test('tampered existing snapshot fails closed', () async {
    final root = await Directory.systemTemp.createTemp(
      'wonderlog-room-snapshot-tamper-',
    );
    try {
      final database = File(
        '${root.path}${Platform.pathSeparator}wanderlog-memories-db',
      );
      await database.writeAsBytes(utf8.encode('room-db'));
      final backupRoot = Directory(
        '${root.path}${Platform.pathSeparator}backups',
      );
      const service = LegacyMigrationSafetySnapshot();

      final first = await service.ensure(
        databaseFile: database,
        backupRoot: backupRoot,
      );
      final copiedDatabase = File(
        '${first.directory.path}${Platform.pathSeparator}'
        'wanderlog-memories-db',
      );
      await copiedDatabase.writeAsString('tampered');

      await expectLater(
        service.ensure(
          databaseFile: database,
          backupRoot: backupRoot,
        ),
        throwsA(isA<StateError>()),
      );
    } finally {
      await root.delete(recursive: true);
    }
  });
}
