import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;
import 'package:wonderlog/core/database/legacy_migration_safety_snapshot.dart';
import 'package:wonderlog/core/database/wonderlog_database.dart';

const _preservedTables = <String>[
  'trips',
  'memories',
  'album_photos',
  'memory_photos',
  'memory_attachments',
  'location_places',
  'geocoding_cache',
  'offline_map_regions',
  'cloud_sync_queue',
];

Future<void> main(List<String> args) async {
  final input = _argument(args, '--input');
  final output = _argument(args, '--output', required: false);

  if (input == null) {
    stderr.writeln(
      'Usage: dart run tool/legacy_room_v6_drill.dart '
      '--input <copy-of-wanderlog-memories-db> [--output <report.json>]',
    );
    exitCode = 64;
    return;
  }

  final source = File(input);
  if (!await source.exists()) {
    stderr.writeln('DRILL BLOCKED: input database does not exist.');
    exitCode = 66;
    return;
  }

  final root =
      await Directory.systemTemp.createTemp('wonderlog-real-room-v6-drill-');
  try {
    final snapshot = await const LegacyMigrationSafetySnapshot().ensure(
      databaseFile: source,
      backupRoot: Directory(
        '${root.path}${Platform.pathSeparator}safety',
      ),
    );

    final sourceHash = await _hash(source);
    final workingDirectory = Directory(
      '${root.path}${Platform.pathSeparator}working',
    );
    await workingDirectory.create(recursive: true);

    final manifestFiles =
        (snapshot.manifest['files']! as List).cast<Map<String, Object?>>();
    for (final entry in manifestFiles) {
      final name = entry['name']! as String;
      await File(
        '${snapshot.directory.path}'
        '${Platform.pathSeparator}$name',
      ).copy(
        '${workingDirectory.path}'
        '${Platform.pathSeparator}$name',
      );
    }

    final workingDatabase = File(
      '${workingDirectory.path}${Platform.pathSeparator}'
      '${source.path.split(Platform.pathSeparator).last}',
    );

    final beforeRaw = sqlite.sqlite3.open(workingDatabase.path);
    late final int beforeVersion;
    late final Map<String, Map<String, Object?>> before;
    try {
      beforeVersion =
          beforeRaw.select('PRAGMA user_version').single.values.single as int;
      if (beforeVersion != 6) {
        throw StateError(
          'Expected Room schema v6, found user_version=$beforeVersion.',
        );
      }
      before = _capture(beforeRaw);
    } finally {
      beforeRaw.dispose();
    }

    final migrated = WonderlogDatabase(NativeDatabase(workingDatabase));
    await migrated.customSelect('SELECT 1').getSingle();
    final versionRow =
        await migrated.customSelect('PRAGMA user_version').getSingle();
    final afterVersion = versionRow.data.values.single as int;
    final fkRows =
        await migrated.customSelect('PRAGMA foreign_key_check').get();
    await migrated.close();

    final afterRaw = sqlite.sqlite3.open(workingDatabase.path);
    late final Map<String, Map<String, Object?>> after;
    try {
      after = _capture(afterRaw);
    } finally {
      afterRaw.dispose();
    }

    final parity = <String, bool>{};
    for (final table in before.keys) {
      parity[table] =
          before[table]!['rowCount'] == after[table]!['rowCount'] &&
          before[table]!['contentSha256'] ==
              after[table]!['contentSha256'];
    }

    final originalStillUnchanged = await _hash(source) == sourceHash;
    final allParity = parity.values.every((value) => value);
    final pass = afterVersion == 9 &&
        fkRows.isEmpty &&
        originalStillUnchanged &&
        allParity;

    final report = <String, Object?>{
      'project': 'Wonderlog',
      'drill': 'Room v6 -> Drift v9',
      'inputKind': 'user-supplied legacy database copy',
      'sourceSha256': sourceHash,
      'sourceUserVersion': beforeVersion,
      'targetUserVersion': afterVersion,
      'foreignKeyViolationCount': fkRows.length,
      'sourceFileUnchanged': originalStillUnchanged,
      'tableParity': parity,
      'before': before,
      'after': after,
      'result': pass ? 'PASS' : 'FAIL',
      'executedAt': DateTime.now().toUtc().toIso8601String(),
      'note':
          'The input file is never opened through Drift; migration runs on '
          'the verified safety-snapshot working copy.',
    };

    final encoded = const JsonEncoder.withIndent(' ').convert(report);
    stdout.writeln(encoded);
    if (output != null) {
      final reportFile = File(output);
      await reportFile.parent.create(recursive: true);
      await reportFile.writeAsString(encoded + '\n', flush: true);
    }

    if (!pass) exitCode = 1;
  } on StateError catch (error) {
    stderr.writeln('DRILL BLOCKED: $error');
    exitCode = 78;
  } finally {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }
}

Map<String, Map<String, Object?>> _capture(sqlite.Database database) {
  final existing = database
      .select(
        "SELECT name FROM sqlite_master "
        "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
      )
      .map((row) => row['name'] as String)
      .toSet();

  final result = <String, Map<String, Object?>>{};
  for (final table in _preservedTables) {
    if (!existing.contains(table)) continue;
    final rows = database.select('SELECT * FROM "$table"');
    final canonicalRows = <String>[];
    for (final row in rows) {
      final record = <String, Object?>{};
      for (final column in rows.columnNames) {
        record[column] = row[column];
      }
      canonicalRows.add(jsonEncode(record));
    }
    canonicalRows.sort();
    result[table] = {
      'rowCount': canonicalRows.length,
      'contentSha256':
          sha256.convert(utf8.encode(canonicalRows.join('\n'))).toString(),
    };
  }
  return result;
}

Future<String> _hash(File file) async =>
    (await sha256.bind(file.openRead()).first).toString();

String? _argument(
  List<String> args,
  String name, {
  bool required = true,
}) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) {
    if (required) return null;
    return null;
  }
  return args[index + 1];
}
