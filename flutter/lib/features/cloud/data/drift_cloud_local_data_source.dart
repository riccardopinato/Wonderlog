import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../core/database/legacy_database_compatibility.dart';
import '../../../core/database/wonderlog_database.dart' as db;
import '../domain/cloud_id_factory.dart';
import '../domain/cloud_local_data_source.dart';
import '../domain/cloud_models.dart';

final class DriftCloudLocalDataSource implements CloudLocalDataSource {
  DriftCloudLocalDataSource({
    required this.database,
    required this.currentUserId,
  });

  final db.WonderlogDatabase database;
  final String? Function() currentUserId;

  @override
  Future<CloudJourney?> getJourneyForCloud(String localId) async {
    final trip = await _trip(localId);
    if (trip == null) return null;
    final owner = _requireUserId();
    final cloudId =
        trip.futureCloudId ?? CloudIdFactory.journey(owner, trip.id);

    return CloudJourney(
      id: cloudId,
      ownerId: owner,
      localReferenceId: trip.id,
      title: trip.title,
      destination: trip.destinationName,
      country: trip.country,
      description: trip.description,
      startDate: trip.startDate,
      endDate: trip.endDate,
      accentTheme: trip.accentTheme,
      coverPhotoCloudId: null,
      createdAt: _date(trip.createdAt),
      updatedAt: _date(trip.updatedAt),
    );
  }

  @override
  Future<CloudMemory?> getMemoryForCloud(String localId) async {
    final memory = await (database.select(database.memories)
          ..where((row) => row.id.equals(localId)))
        .getSingleOrNull();
    if (memory == null) return null;

    final trip = await _trip(memory.tripId);
    final journeyCloudId = trip?.futureCloudId;
    if (journeyCloudId == null || journeyCloudId.isEmpty) return null;

    final owner = _requireUserId();
    final cloudId =
        memory.futureCloudId ?? CloudIdFactory.memory(owner, memory.id);

    return CloudMemory(
      id: cloudId,
      ownerId: owner,
      journeyCloudId: journeyCloudId,
      localReferenceId: memory.id,
      title: memory.title,
      journalText:
          memory.journalText.isEmpty ? memory.note : memory.journalText,
      date: memory.date,
      locationName:
          memory.locationName.trim().isEmpty ? null : memory.locationName,
      latitude: memory.latitude,
      longitude: memory.longitude,
      mood: memory.mood,
      tags: _tags(memory.tagsJson),
      createdAt: _date(memory.createdAt),
      updatedAt: _date(memory.updatedAt),
    );
  }

  @override
  Future<CloudAlbumPhoto?> getPhotoForCloud(String localId) async {
    final photo = await _photo(localId);
    if (photo == null) return null;

    final trip = await _trip(photo.journeyId);
    final journeyCloudId = trip?.futureCloudId;
    if (journeyCloudId == null || journeyCloudId.isEmpty) return null;

    final owner = _requireUserId();
    final cloudId =
        photo.futureCloudId ?? CloudIdFactory.photo(owner, photo.id);

    return CloudAlbumPhoto(
      id: cloudId,
      ownerId: owner,
      journeyCloudId: journeyCloudId,
      localReferenceId: photo.id,
      remoteFilePath: null,
      fileName: photo.fileName,
      mimeType: photo.mimeType,
      capturedAt: photo.capturedAt == null ? null : _date(photo.capturedAt!),
      latitude: photo.gpsLatitude,
      longitude: photo.gpsLongitude,
      locationName:
          photo.locationName.trim().isEmpty ? null : photo.locationName,
      displayOrder: photo.displayOrder,
      isCoverPhoto: photo.isCoverPhoto,
      createdAt: _date(photo.createdAt),
      updatedAt: _date(photo.updatedAt),
    );
  }

  @override
  Future<String?> getPhotoLocalReference(String localId) async =>
      (await _photo(localId))?.localUri;

  @override
  Future<String> buildRemotePhotoPath(String localId) async {
    final owner = _requireUserId();
    final photo = await _photo(localId);
    if (photo == null) throw StateError('Photo not found.');

    final name = photo.fileName.trim();
    final extension = name.contains('.')
        ? name.split('.').last.toLowerCase()
        : 'jpg';
    final safeExtension = RegExp(r'^[a-z0-9]{1,8}$').hasMatch(extension)
        ? extension
        : 'jpg';

    return owner +
        '/journeys/' +
        photo.journeyId +
        '/photos/' +
        photo.id +
        '.' +
        safeExtension;
  }

  @override
  Future<void> markJourneySynced(String localId, String cloudId) async {
    await (database.update(database.trips)
          ..where((row) => row.id.equals(localId)))
        .write(
      db.TripsCompanion(
        futureCloudId: Value(cloudId),
        syncStatus: const Value('SYNCED'),
      ),
    );
  }

  @override
  Future<void> markMemorySynced(String localId, String cloudId) async {
    await (database.update(database.memories)
          ..where((row) => row.id.equals(localId)))
        .write(
      db.MemoriesCompanion(
        futureCloudId: Value(cloudId),
        syncStatus: const Value('SYNCED'),
      ),
    );
  }

  @override
  Future<void> markPhotoSynced(
    String localId,
    String cloudId,
    String? remotePath,
  ) async {
    await (database.update(database.albumPhotos)
          ..where((row) => row.id.equals(localId)))
        .write(
      db.AlbumPhotosCompanion(
        futureCloudId: Value(cloudId),
        syncStatus: const Value('SYNCED'),
      ),
    );
  }

  @override
  Future<String?> getJourneyCloudId(String localId) async =>
      (await _trip(localId))?.futureCloudId;

  @override
  Future<String?> getMemoryCloudId(String localId) async {
    final row = await (database.select(database.memories)
          ..where((item) => item.id.equals(localId)))
        .getSingleOrNull();
    return row?.futureCloudId;
  }

  @override
  Future<PhotoCloudDeleteInfo?> getPhotoCloudDeleteInfo(
    String localId,
  ) async {
    final photo = await _photo(localId);
    final cloudId = photo?.futureCloudId;
    if (photo == null || cloudId == null || cloudId.isEmpty) return null;
    return PhotoCloudDeleteInfo(
      cloudId: cloudId,
      remoteFilePath: await buildRemotePhotoPath(localId),
    );
  }

  @override
  Future<List<String>> getPendingJourneyIds() async {
    final rows = await (database.select(database.trips)
          ..where((row) => row.syncStatus.isIn(_pendingStatuses)))
        .get();
    return rows.map((row) => row.id).toList(growable: false);
  }

  @override
  Future<List<String>> getPendingMemoryIds() async {
    final rows = await (database.select(database.memories)
          ..where((row) => row.syncStatus.isIn(_pendingStatuses)))
        .get();
    return rows.map((row) => row.id).toList(growable: false);
  }

  @override
  Future<List<String>> getPendingPhotoIds() async {
    final rows = await (database.select(database.albumPhotos)
          ..where((row) => row.syncStatus.isIn(_pendingStatuses)))
        .get();
    return rows.map((row) => row.id).toList(growable: false);
  }

  Future<db.Trip?> _trip(String id) =>
      (database.select(database.trips)..where((row) => row.id.equals(id)))
          .getSingleOrNull();

  Future<db.AlbumPhoto?> _photo(String id) =>
      (database.select(database.albumPhotos)
            ..where((row) => row.id.equals(id)))
          .getSingleOrNull();

  String _requireUserId() {
    final id = currentUserId()?.trim();
    if (id == null || id.isEmpty) {
      throw StateError('Cloud backup requires an authenticated account.');
    }
    return id;
  }

  DateTime _date(int millis) =>
      DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);

  List<String> _tags(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((item) => item.toString()).toList(growable: false);
      }
    } catch (_) {
      // Room v6 converter compatibility below.
    }
    return LegacyDatabaseCompatibility.decodeLegacyTags(raw);
  }

  static const _pendingStatuses = [
    'LOCAL_ONLY',
    'PENDING_UPLOAD',
    'ERROR',
  ];
}
