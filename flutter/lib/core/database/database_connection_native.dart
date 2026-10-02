import 'package:drift/drift.dart';
import 'package:drift/native.dart';

QueryExecutor driftDatabase({required String name}) => NativeDatabase.memory();
