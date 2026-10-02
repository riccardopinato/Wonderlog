import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart' as drift_flutter;
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
          if (await File(legacyPath).exists()) {
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
