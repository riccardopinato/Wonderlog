import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart' as drift_flutter;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'legacy_database_compatibility.dart';
import 'legacy_migration_safety_snapshot.dart';
import 'legacy_room_schema_normalizer.dart';

const _legacyRoomDatabaseName = 'wanderlog-memories-db';

QueryExecutor driftDatabase({required String name}) {
  return drift_flutter.driftDatabase(
    name: name,
    native: drift_flutter.DriftNativeOptions(
      databasePath: () async {
        final documents = await getApplicationDocumentsDirectory();

        // The production Kotlin/Room app stores the database in Android's
        // standard /databases directory with this exact filename. Reusing it
        // means an APK update can migrate in place instead of silently
        // starting with an empty Flutter database.
        if (defaultTargetPlatform == TargetPlatform.android) {
          final appDataDirectory = documents.parent;
          final legacyPath = p.join(
            appDataDirectory.path,
            'databases',
            _legacyRoomDatabaseName,
          );
          final legacyDatabase = File(legacyPath);
          if (await legacyDatabase.exists()) {
            final schemaVersion = _readUserVersion(legacyDatabase);
            if (LegacyDatabaseCompatibility.isFutureSchema(schemaVersion)) {
              throw StateError(
                'Legacy database schema v$schemaVersion is newer than '
                'supported Drift schema v'
                '${LegacyDatabaseCompatibility.flutterSchemaVersion}.',
              );
            }
            if (!LegacyDatabaseCompatibility.canOpenLegacyDatabase(
              schemaVersion,
            )) {
              throw StateError(
                'Legacy database schema v$schemaVersion is not a certified '
                'Wonderlog cutover baseline. Supported legacy Room baseline: '
                'v${LegacyDatabaseCompatibility.roomSchemaVersion}; current '
                'Flutter schema: '
                'v${LegacyDatabaseCompatibility.flutterSchemaVersion}.',
              );
            }

            if (LegacyDatabaseCompatibility.requiresPreMigrationSnapshot(
              schemaVersion,
            )) {
              final backupRoot = Directory(
                p.join(
                  documents.path,
                  'wonderlog_migration_backups',
                ),
              );
              await const LegacyMigrationSafetySnapshot().ensure(
                databaseFile: legacyDatabase,
                backupRoot: backupRoot,
              );
              const LegacyRoomSchemaNormalizer().normalize(legacyDatabase);
            }
            return legacyPath;
          }
        }

        // iOS and fresh installs use Drift's cross-platform file in the
        // documents directory. This also keeps pre-cutover Flutter test
        // installations stable.
        return p.join(documents.path, name + '.sqlite');
      },
      shareAcrossIsolates: true,
    ),
  );
}

int _readUserVersion(File databaseFile) {
  final database = sqlite.sqlite3.open(
    databaseFile.path,
    mode: sqlite.OpenMode.readOnly,
  );
  try {
    final row = database.select('PRAGMA user_version').single;
    return row.values.single as int;
  } finally {
    database.dispose();
  }
}
