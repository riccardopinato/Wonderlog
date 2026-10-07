import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'package:wonderlog/core/database/wonderlog_database.dart';

void main() {
  test('Flutter v9 physical schema remains snake_case across reopen', () async {
    final directory =
        await Directory.systemTemp.createTemp('wonderlog-flutter-v9-reopen-');
    final file = File(
      '${directory.path}${Platform.pathSeparator}wonderlog_flutter.sqlite',
    );

    try {
      final first = WonderlogDatabase(NativeDatabase(file));
      await first.into(first.trips).insert(
            TripsCompanion.insert(
              id: 'flutter-v9-trip',
              destinationName: 'Padova',
              startDate: '2026-10-07',
              endDate: '2026-10-07',
              title: 'Padova',
              destination: 'Padova',
              createdAt: 1791340800000,
              updatedAt: 1791340800000,
            ),
          );
      await first.close();

      final raw = sqlite.sqlite3.open(file.path);
      try {
        expect(
          raw.select('PRAGMA user_version').single.values.single,
          9,
        );
        final columns = raw
            .select('PRAGMA table_info("trips")')
            .map((row) => row['name'] as String)
            .toSet();
        expect(columns, contains('destination_name'));
        expect(columns, isNot(contains('destinationName')));
        expect(columns, contains('created_at'));
        expect(columns, isNot(contains('createdAt')));
      } finally {
        raw.dispose();
      }

      final reopened = WonderlogDatabase(NativeDatabase(file));
      final trip = await (reopened.select(reopened.trips)
            ..where((row) => row.id.equals('flutter-v9-trip')))
          .getSingle();
      expect(trip.destinationName, 'Padova');
      expect(trip.title, 'Padova');
      await reopened.close();
    } finally {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  });
}
