import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/legacy_database_compatibility.dart';
import '../../../core/database/wonderlog_database.dart' as db;
import '../../journeys/domain/journey.dart';
import '../domain/memory_models.dart';
import '../domain/wonderlog_repository.dart';

final class DriftWonderlogRepository implements WonderlogRepository {
  DriftWonderlogRepository(this.database);

  final db.WonderlogDatabase database;
  final Uuid _uuid = const Uuid();

  @override
  Stream<List<Journey>> watchJourneys() {
    final query = database.select(database.trips)
      ..where((row) => row.archived.equals(false))
      ..orderBy([(row) => OrderingTerm.desc(row.startDate)]);
    return query.watch().map(
      (rows) => rows.map(_journey).toList(growable: false),
    );
  }

  @override
  Stream<Journey?> watchJourney(String id) {
    final query = database.select(database.trips)
      ..where((row) => row.id.equals(id));
    return query.watchSingleOrNull().map(
      (row) => row == null ? null : _journey(row),
    );
  }

  @override
  Stream<List<Journey>> watchArchivedJourneys() {
    final query = database.select(database.trips)
      ..where((row) => row.archived.equals(true))
      ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
    return query.watch().map(
      (rows) => rows.map(_journey).toList(growable: false),
    );
  }

  @override
  Stream<List<MemoryEntry>> watchMemories(String journeyId) {
    final query = database.select(database.memories)
      ..where((row) => row.tripId.equals(journeyId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.date),
        (row) => OrderingTerm.asc(row.displayOrder),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);
    return query.watch().map(
      (rows) => rows.map(_memory).toList(growable: false),
    );
  }

  @override
  Stream<List<MemoryEntry>> watchAllMemories() {
    final query = database.select(database.memories)
      ..orderBy([
        (row) => OrderingTerm.desc(row.date),
        (row) => OrderingTerm.desc(row.updatedAt),
      ]);
    return query.watch().map(
      (rows) => rows.map(_memory).toList(growable: false),
    );
  }

  @override
  Stream<List<MemoryEntry>> watchUnassignedMemories() {
    final query = database.select(database.memories)
      ..where(
        (row) => row.tripId.isNull() & row.journeyId.isNull(),
      )
      ..orderBy([
        (row) => OrderingTerm.desc(row.date),
        (row) => OrderingTerm.desc(row.updatedAt),
      ]);
    return query.watch().map(
      (rows) => rows.map(_memory).toList(growable: false),
    );
  }

  @override
  Stream<List<MemoryWithPhotos>> watchMemoriesWithPhotos(
    String journeyId,
  ) {
    final query = database.select(database.memories)
      ..where((row) => row.tripId.equals(journeyId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.date),
        (row) => OrderingTerm.asc(row.displayOrder),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);

    return query.watch().asyncMap(_memoryBundles);
  }

  @override
  Stream<List<MemoryWithPhotos>> watchAllMemoriesWithPhotos() {
    final query = database.select(database.memories)
      ..orderBy([
        (row) => OrderingTerm.desc(row.date),
        (row) => OrderingTerm.desc(row.updatedAt),
      ]);
    return query.watch().asyncMap(_memoryBundles);
  }

  @override
  Stream<List<AlbumPhotoEntry>> watchAlbum(String journeyId) {
    final query = database.select(database.albumPhotos)
      ..where((row) => row.journeyId.equals(journeyId))
      ..orderBy([
        (row) => OrderingTerm.asc(row.displayOrder),
        (row) => OrderingTerm.asc(row.createdAt),
      ]);
    return query.watch().map(
      (rows) => rows.map(_photo).toList(growable: false),
    );
  }

  @override
  Stream<List<AlbumPhotoEntry>> watchAllPhotos() {
    final query = database.select(database.albumPhotos)
      ..orderBy([
        (row) => OrderingTerm.desc(row.capturedAt),
        (row) => OrderingTerm.desc(row.createdAt),
      ]);
    return query.watch().map(
      (rows) => rows.map(_photo).toList(growable: false),
    );
  }

  @override
  Stream<List<MemoryAttachment>> watchAttachments(String memoryId) {
    final query = database.select(database.memoryAttachments)
      ..where((row) => row.memoryId.equals(memoryId))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);
    return query.watch().map(
      (rows) => rows.map(_attachment).toList(growable: false),
    );
  }

  @override
  Stream<MemoryWithPhotos?> watchMemory(String memoryId) {
    final query = database.select(database.memories)
      ..where((row) => row.id.equals(memoryId));

    return query.watchSingleOrNull().asyncMap((row) async {
      if (row == null) return null;

      final links = await (database.select(database.memoryPhotos)
            ..where((link) => link.memoryId.equals(memoryId))
            ..orderBy([(link) => OrderingTerm.asc(link.displayOrder)]))
          .get();

      final photos = <AlbumPhotoEntry>[];
      for (final link in links) {
        final photo = await (database.select(database.albumPhotos)
              ..where((item) => item.id.equals(link.albumPhotoId)))
            .getSingleOrNull();
        if (photo != null) photos.add(_photo(photo));
      }

      final attachments = await (database.select(database.memoryAttachments)
            ..where((item) => item.memoryId.equals(memoryId))
            ..orderBy([(item) => OrderingTerm.asc(item.createdAt)]))
          .get();

      return MemoryWithPhotos(
        memory: _memory(row),
        photos: photos,
        attachments: attachments.map(_attachment).toList(growable: false),
      );
    });
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
    final journey = Journey(
      id: _uuid.v4(),
      title: normalizedTitle,
      destination: normalizedDestination,
      country: country.trim(),
      startDate: startDate,
      endDate: endDate,
      description: description.trim(),
      latitude: 0,
      longitude: 0,
      favorite: false,
      archived: false,
      createdAt: now,
      updatedAt: now,
    );
    await saveJourney(journey);
    return journey;
  }

  @override
  Future<void> saveJourney(Journey journey) =>
      database.into(database.trips).insertOnConflictUpdate(
        db.TripsCompanion.insert(
          id: journey.id,
          destinationName: journey.destination,
          country: Value(journey.country),
          startDate: _dateOnly(journey.startDate),
          endDate: _dateOnly(journey.endDate),
          description: Value(journey.description),
          title: journey.title,
          destination: journey.destination,
          latitude: Value(journey.latitude),
          longitude: Value(journey.longitude),
          createdAt: journey.createdAt.toUtc().millisecondsSinceEpoch,
          updatedAt: journey.updatedAt.toUtc().millisecondsSinceEpoch,
          favorite: Value(journey.favorite),
          archived: Value(journey.archived),
        ),
      );

  @override
  Future<void> setJourneyArchived(String journeyId, bool archived) async {
    await (database.update(database.trips)
          ..where((row) => row.id.equals(journeyId)))
        .write(
      db.TripsCompanion(
        archived: Value(archived),
        updatedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<JourneyDeletionImpact> getJourneyDeletionImpact(
    String journeyId,
  ) async {
    final memoryRows = await (database.select(database.memories)
          ..where(
            (row) =>
                row.tripId.equals(journeyId) |
                row.journeyId.equals(journeyId),
          ))
        .get();
    final photoRows = await (database.select(database.albumPhotos)
          ..where((row) => row.journeyId.equals(journeyId)))
        .get();

    var attachmentCount = 0;
    for (final memory in memoryRows) {
      attachmentCount += await (database.select(database.memoryAttachments)
            ..where((row) => row.memoryId.equals(memory.id)))
          .get()
          .then((rows) => rows.length);
    }

    return JourneyDeletionImpact(
      memoryCount: memoryRows.length,
      photoCount: photoRows.length,
      attachmentCount: attachmentCount,
    );
  }

  @override
  Future<void> deleteJourney(String journeyId) async {
    await (database.delete(database.trips)
          ..where((row) => row.id.equals(journeyId)))
        .go();
  }

  @override
  Future<void> saveMemory(MemoryEntry memory) =>
      database.into(database.memories).insertOnConflictUpdate(
        db.MemoriesCompanion.insert(
          id: memory.id,
          tripId: Value(memory.journeyId),
          journeyId: Value(memory.journeyId),
          title: memory.title,
          journalText: Value(memory.journalText),
          locationName: Value(memory.locationName),
          latitude: Value(memory.latitude),
          longitude: Value(memory.longitude),
          date: _dateOnly(memory.date),
          mood: Value(memory.mood.name.toUpperCase()),
          tagsJson: Value(jsonEncode(memory.tags)),
          favorite: Value(memory.favorite),
          createdAt: memory.createdAt.toUtc().millisecondsSinceEpoch,
          updatedAt: memory.updatedAt.toUtc().millisecondsSinceEpoch,
          displayOrder: Value(memory.displayOrder),
          syncStatus: Value(memory.syncStatus),
          futureCloudId: Value(memory.futureCloudId),
        ),
      );

  @override
  Future<void> moveMemoryToJourney(
    String memoryId,
    String? journeyId,
  ) async {
    if (journeyId != null) {
      final journey = await (database.select(database.trips)
            ..where((row) => row.id.equals(journeyId)))
          .getSingleOrNull();
      if (journey == null) {
        throw StateError('Journey not found.');
      }
    }

    await (database.update(database.memories)
          ..where((row) => row.id.equals(memoryId)))
        .write(
      db.MemoriesCompanion(
        tripId: Value(journeyId),
        journeyId: Value(journeyId),
        updatedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  @override
  Future<void> deleteMemory(String memoryId) async {
    await (database.delete(database.memories)
          ..where((row) => row.id.equals(memoryId)))
        .go();
  }

  @override
  Future<void> savePhoto(AlbumPhotoEntry photo) =>
      database.into(database.albumPhotos).insertOnConflictUpdate(
        db.AlbumPhotosCompanion.insert(
          id: photo.id,
          journeyId: photo.journeyId,
          localUri: photo.localUri,
          thumbnailUri: Value(photo.thumbnailUri),
          originalUri: Value(photo.originalUri),
          fileName: Value(photo.fileName),
          mimeType: Value(photo.mimeType),
          width: Value(photo.width),
          height: Value(photo.height),
          fileSize: Value(photo.fileSize),
          createdAt: photo.createdAt.toUtc().millisecondsSinceEpoch,
          updatedAt: photo.updatedAt.toUtc().millisecondsSinceEpoch,
          capturedAt: Value(photo.capturedAt?.toUtc().millisecondsSinceEpoch),
          gpsLatitude: Value(photo.gpsLatitude),
          gpsLongitude: Value(photo.gpsLongitude),
          locationName: Value(photo.locationName),
          favorite: Value(photo.favorite),
          isCoverPhoto: Value(photo.isCoverPhoto),
          displayOrder: Value(photo.displayOrder),
          syncStatus: Value(photo.syncStatus),
          futureCloudId: Value(photo.futureCloudId),
        ),
      );

  @override
  Future<void> deletePhoto(String photoId) async {
    final links = await (database.select(database.memoryPhotos)
          ..where((row) => row.albumPhotoId.equals(photoId)))
        .get();
    await (database.delete(database.albumPhotos)
          ..where((row) => row.id.equals(photoId)))
        .go();
    for (final memoryId in links.map((link) => link.memoryId).toSet()) {
      await _touchMemory(memoryId);
    }
  }

  @override
  Future<void> linkPhotoToMemory({
    required String memoryId,
    required String photoId,
    required int displayOrder,
    required bool isHero,
  }) async {
    await database.into(database.memoryPhotos).insertOnConflictUpdate(
          db.MemoryPhotosCompanion.insert(
            memoryId: memoryId,
            albumPhotoId: photoId,
            displayOrder: Value(displayOrder),
            isHeroPhoto: Value(isHero),
          ),
        );
    await _touchMemory(memoryId);
  }

  @override
  Future<void> replaceMemoryPhotoLinks({
    required String memoryId,
    required List<String> photoIds,
  }) async {
    await database.transaction(() async {
      await (database.delete(database.memoryPhotos)
            ..where((row) => row.memoryId.equals(memoryId)))
          .go();
      for (var index = 0; index < photoIds.length; index++) {
        await database.into(database.memoryPhotos).insertOnConflictUpdate(
              db.MemoryPhotosCompanion.insert(
                memoryId: memoryId,
                albumPhotoId: photoIds[index],
                displayOrder: Value(index),
                isHeroPhoto: Value(index == 0),
              ),
            );
      }
      await _touchMemory(memoryId);
    });
  }

  @override
  Future<void> unlinkPhotoFromMemory({
    required String memoryId,
    required String photoId,
  }) async {
    await (database.delete(database.memoryPhotos)
          ..where(
            (row) =>
                row.memoryId.equals(memoryId) &
                row.albumPhotoId.equals(photoId),
          ))
        .go();
    await _touchMemory(memoryId);
  }

  @override
  Future<void> setJourneyCoverPhoto({
    required String journeyId,
    String? photoId,
  }) async {
    await database.transaction(() async {
      await (database.update(database.albumPhotos)
            ..where((row) => row.journeyId.equals(journeyId)))
          .write(
        const db.AlbumPhotosCompanion(
          isCoverPhoto: Value(false),
        ),
      );

      if (photoId == null) return;

      final updated = await (database.update(database.albumPhotos)
            ..where(
              (row) =>
                  row.journeyId.equals(journeyId) &
                  row.id.equals(photoId),
            ))
          .write(
        const db.AlbumPhotosCompanion(
          isCoverPhoto: Value(true),
        ),
      );
      if (updated != 1) {
        throw StateError('Cover photo not found in Journey.');
      }
    });
  }

  @override
  Future<Set<String>> referencedMediaUris() async {
    final photos = await database.select(database.albumPhotos).get();
    final attachments =
        await database.select(database.memoryAttachments).get();
    return <String>{
      for (final photo in photos) photo.localUri,
      for (final attachment in attachments) attachment.localUri,
    };
  }

  @override
  Future<void> saveAttachment(MemoryAttachment attachment) async {
    await database.into(database.memoryAttachments).insertOnConflictUpdate(
          db.MemoryAttachmentsCompanion.insert(
            id: attachment.id,
            memoryId: attachment.memoryId,
            localUri: attachment.localUri,
            originalName: Value(attachment.originalName),
            mimeType: attachment.mimeType,
            attachmentType: attachment.attachmentType,
            createdAt: attachment.createdAt.toUtc().millisecondsSinceEpoch,
            syncStatus: Value(attachment.syncStatus),
          ),
        );
    await _touchMemory(attachment.memoryId);
  }

  @override
  Future<void> deleteAttachment(String attachmentId) async {
    final attachment = await (database.select(database.memoryAttachments)
          ..where((row) => row.id.equals(attachmentId)))
        .getSingleOrNull();
    await (database.delete(database.memoryAttachments)
          ..where((row) => row.id.equals(attachmentId)))
        .go();
    if (attachment != null) {
      await _touchMemory(attachment.memoryId);
    }
  }

  Future<void> _touchMemory(String memoryId) async {
    await (database.update(database.memories)
          ..where((row) => row.id.equals(memoryId)))
        .write(
      db.MemoriesCompanion(
        updatedAt: Value(DateTime.now().toUtc().millisecondsSinceEpoch),
      ),
    );
  }

  Future<List<MemoryWithPhotos>> _memoryBundles(
    List<db.Memory> rows,
  ) async {
    final result = <MemoryWithPhotos>[];
    for (final row in rows) {
      final links = await (database.select(database.memoryPhotos)
            ..where((link) => link.memoryId.equals(row.id))
            ..orderBy([(link) => OrderingTerm.asc(link.displayOrder)]))
          .get();
      final photos = <AlbumPhotoEntry>[];
      for (final link in links) {
        final photo = await (database.select(database.albumPhotos)
              ..where((item) => item.id.equals(link.albumPhotoId)))
            .getSingleOrNull();
        if (photo != null) photos.add(_photo(photo));
      }
      final attachments = await (database.select(database.memoryAttachments)
            ..where((item) => item.memoryId.equals(row.id))
            ..orderBy([(item) => OrderingTerm.asc(item.createdAt)]))
          .get();
      result.add(
        MemoryWithPhotos(
          memory: _memory(row),
          photos: photos,
          attachments: attachments.map(_attachment).toList(growable: false),
        ),
      );
    }
    return result;
  }

  Journey _journey(db.Trip row) => Journey(
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
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.createdAt,
          isUtc: true,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.updatedAt,
          isUtc: true,
        ),
      );

  MemoryEntry _memory(db.Memory row) {
    var mood = Mood.calm;
    for (final candidate in Mood.values) {
      if (candidate.name.toUpperCase() == row.mood) {
        mood = candidate;
        break;
      }
    }
    return MemoryEntry(
      id: row.id,
      journeyId: row.tripId ?? row.journeyId,
      title: row.title,
      journalText: row.journalText.isEmpty ? row.note : row.journalText,
      locationName: row.locationName,
      latitude: row.latitude,
      longitude: row.longitude,
      date: DateTime.parse(row.date),
      mood: mood,
      tags: _tags(row.tagsJson),
      favorite: row.favorite,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row.createdAt,
        isUtc: true,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row.updatedAt,
        isUtc: true,
      ),
      displayOrder: row.displayOrder,
      syncStatus: row.syncStatus,
      futureCloudId: row.futureCloudId,
    );
  }

  List<String> _tags(String raw) {
    try {
      final value = jsonDecode(raw);
      if (value is List) {
        return value.whereType<String>().toList(growable: false);
      }
    } catch (_) {
      // Kotlin Room v6 used Converters.fromStringList(), which persisted tags
      // as a "||"-delimited string instead of JSON.
    }

    return LegacyDatabaseCompatibility.decodeLegacyTags(raw);
  }

  AlbumPhotoEntry _photo(db.AlbumPhoto row) => AlbumPhotoEntry(
        id: row.id,
        journeyId: row.journeyId,
        localUri: row.localUri,
        thumbnailUri: row.thumbnailUri,
        originalUri: row.originalUri,
        fileName: row.fileName,
        mimeType: row.mimeType,
        width: row.width,
        height: row.height,
        fileSize: row.fileSize,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.createdAt,
          isUtc: true,
        ),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(
          row.updatedAt,
          isUtc: true,
        ),
        capturedAt: row.capturedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                row.capturedAt!,
                isUtc: true,
              ),
        gpsLatitude: row.gpsLatitude,
        gpsLongitude: row.gpsLongitude,
        locationName: row.locationName,
        favorite: row.favorite,
        isCoverPhoto: row.isCoverPhoto,
        displayOrder: row.displayOrder,
        syncStatus: row.syncStatus,
        futureCloudId: row.futureCloudId,
      );

  MemoryAttachment _attachment(db.MemoryAttachment row) => MemoryAttachment(
        id: row.id,
        memoryId: row.memoryId,
        localUri: row.localUri,
        originalName: row.originalName,
        mimeType: row.mimeType,
        attachmentType: row.attachmentType,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          row.createdAt,
          isUtc: true,
        ),
        syncStatus: row.syncStatus,
      );

  String _dateOnly(DateTime value) {
    final local = value.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return year + '-' + month + '-' + day;
  }
}
