import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart' as drift_flutter;

/// Drift web runs SQLite in a worker. Both assets are distributed with
/// the Flutter Web bundle at the app's base href (e.g. /Wonderlog/).
/// Do not use the native default connection, which cannot discover these files.
QueryExecutor driftDatabase({required String name}) =>
    drift_flutter.driftDatabase(
      name: name,
      web: drift_flutter.DriftWebOptions(
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
