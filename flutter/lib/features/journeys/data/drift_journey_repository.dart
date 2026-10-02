import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/wonderlog_database.dart';
import '../domain/journey.dart';
import '../domain/journey_repository.dart';

final class DriftJourneyRepository implements JourneyRepository {
  DriftJourneyRepository(this._database);

  final WonderlogDatabase _database;
  final Uuid _uuid = const Uuid();

  @override
  Stream<List<Journey>> watchJourneys() {
    final query = _database.select(_database.trips)
      ..where((table) => table.archived.equals(false))
      ..orderBy([
        (table) => OrderingTerm(
              expression: table.startDate,
              mode: OrderingMode.desc,
            ),
      ]);

    return query.watch().map(
          (rows) => rows.map(_mapJourney).toList(growable: false),
        );
  }

  @override
  Future<Journey> createJourney({
    required String title,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    String country = '',
    String description = '',
  }) async {
    final normalizedTitle = title.trim();
    final normalizedDestination = destination.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Title is required.');
    }
    if (normalizedDestination.isEmpty) {
      throw ArgumentError.value(
        destination,
        'destination',
        'Destination is required.',
      );
    }
    if (endDate.isBefore(startDate)) {
      throw ArgumentError('End date cannot be before start date.');
    }

    final now = DateTime.now().toUtc();
    final id = _uuid.v4();

    await _database.into(_database.trips).insert(
          TripsCompanion.insert(
            id: id,
            destinationName: normalizedDestination,
            country: Value(country.trim()),
            startDate: _dateOnly(startDate),
            endDate: _dateOnly(endDate),
            description: Value(description.trim()),
            title: normalizedTitle,
            destination: normalizedDestination,
            createdAt: now.millisecondsSinceEpoch,
            updatedAt: now.millisecondsSinceEpoch,
          ),
        );

    final row = await (_database.select(_database.trips)
          ..where((table) => table.id.equals(id)))
        .getSingle();

    return _mapJourney(row);
  }

  Journey _mapJourney(Trip row) => Journey(
        id: row.id,
        title: row.title,
        destination: row.destination,
        country: row.country,
        startDate: DateTime.parse(row.startDate),
        endDate: DateTime.parse(row.endDate),
        description: row.description,
        latitude: row.latitude,
        longitude: row.longitude,
        favorite: row.favorite,
        archived: row.archived,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(row.createdAt, isUtc: true),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(row.updatedAt, isUtc: true),
      );

  String _dateOnly(DateTime value) {
    final date = value.toLocal();
    return date.year.toString().padLeft(4, '0') +
        '-' +
        date.month.toString().padLeft(2, '0') +
        '-' +
        date.day.toString().padLeft(2, '0');
  }
}
