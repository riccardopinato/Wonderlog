import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart' as drift_flutter;

QueryExecutor driftDatabase({required String name}) =>
    drift_flutter.driftDatabase(name: name);
