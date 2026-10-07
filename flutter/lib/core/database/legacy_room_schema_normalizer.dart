import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite;

import 'legacy_database_compatibility.dart';

/// Converts only the certified Kotlin/Room v6 physical column names into the
/// snake_case names used by Wonderlog's existing Flutter/Drift v9 schema.
///
/// The operation is transactional and idempotent so a process interruption
/// between normalization and Drift's v6 -> v9 migration can be retried safely.
/// A verified migration safety snapshot must be created before this runs.
final class LegacyRoomSchemaNormalizer {
  const LegacyRoomSchemaNormalizer();

  static const Map<String, Map<String, String>> _renames = {
    'trips': {
      'destinationName': 'destination_name',
      'startDate': 'start_date',
      'endDate': 'end_date',
      'coverImage': 'cover_image',
      'accentGradientIndex': 'accent_gradient_index',
      'coverPhotoId': 'cover_photo_id',
      'accentTheme': 'accent_theme',
      'createdAt': 'created_at',
      'updatedAt': 'updated_at',
      'futureCloudId': 'future_cloud_id',
      'syncStatus': 'sync_status',
    },
    'memories': {
      'tripId': 'trip_id',
      'journeyId': 'journey_id',
      'journalText': 'journal_text',
      'locationName': 'location_name',
      'createdAt': 'created_at',
      'updatedAt': 'updated_at',
      'displayOrder': 'display_order',
      'syncStatus': 'sync_status',
      'futureCloudId': 'future_cloud_id',
    },
    'album_photos': {
      'journeyId': 'journey_id',
      'localUri': 'local_uri',
      'thumbnailUri': 'thumbnail_uri',
      'originalUri': 'original_uri',
      'fileName': 'file_name',
      'mimeType': 'mime_type',
      'fileSize': 'file_size',
      'createdAt': 'created_at',
      'updatedAt': 'updated_at',
      'capturedAt': 'captured_at',
      'gpsLatitude': 'gps_latitude',
      'gpsLongitude': 'gps_longitude',
      'locationName': 'location_name',
      'isCoverPhoto': 'is_cover_photo',
      'displayOrder': 'display_order',
      'syncStatus': 'sync_status',
      'futureCloudId': 'future_cloud_id',
    },
    'memory_photos': {
      'memoryId': 'memory_id',
      'albumPhotoId': 'album_photo_id',
      'displayOrder': 'display_order',
      'isHeroPhoto': 'is_hero_photo',
    },
    'memory_attachments': {
      'memoryId': 'memory_id',
      'localUri': 'local_uri',
      'originalName': 'original_name',
      'mimeType': 'mime_type',
      'attachmentType': 'attachment_type',
      'createdAt': 'created_at',
      'syncStatus': 'sync_status',
    },
    'location_places': {
      'displayName': 'display_name',
    },
    'geocoding_cache': {
      'displayName': 'display_name',
      'cachedAt': 'cached_at',
    },
    'offline_map_regions': {
      'centerLatitude': 'center_latitude',
      'centerLongitude': 'center_longitude',
      'radiusKm': 'radius_km',
      'zoomMin': 'zoom_min',
      'zoomMax': 'zoom_max',
      'sizeBytes': 'size_bytes',
      'isDownloaded': 'is_downloaded',
      'downloadProgress': 'download_progress',
      'createdAt': 'created_at',
    },
    'cloud_sync_queue': {
      'entityType': 'entity_type',
      'localEntityId': 'local_entity_id',
      'createdAt': 'created_at',
      'attemptCount': 'attempt_count',
      'lastError': 'last_error',
    },
  };

  void normalize(File databaseFile) {
    final database = sqlite.sqlite3.open(databaseFile.path);
    try {
      final version =
          database.select('PRAGMA user_version').single.values.single as int;
      if (version != LegacyDatabaseCompatibility.roomSchemaVersion) {
        throw StateError(
          'Room schema normalization requires v'
          '${LegacyDatabaseCompatibility.roomSchemaVersion}, found v$version.',
        );
      }

      final tables = database
          .select(
            "SELECT name FROM sqlite_master "
            "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'",
          )
          .map((row) => row['name'] as String)
          .toSet();
      final missing =
          _renames.keys.where((table) => !tables.contains(table)).toList();
      if (missing.isNotEmpty) {
        throw StateError(
          'Certified Room v6 database is missing required tables: '
          '${missing.join(', ')}.',
        );
      }

      database.execute('PRAGMA foreign_keys = ON');
      database.execute('BEGIN IMMEDIATE');
      try {
        for (final tableEntry in _renames.entries) {
          for (final rename in tableEntry.value.entries) {
            _renameColumn(
              database,
              table: tableEntry.key,
              legacyName: rename.key,
              driftName: rename.value,
            );
          }
        }

        final violations = database.select('PRAGMA foreign_key_check');
        if (violations.isNotEmpty) {
          throw StateError(
            'Room v6 normalization produced '
            '${violations.length} foreign-key violation(s).',
          );
        }

        database.execute('COMMIT');
      } catch (_) {
        database.execute('ROLLBACK');
        rethrow;
      }
    } finally {
      database.dispose();
    }
  }

  void _renameColumn(
    sqlite.Database database, {
    required String table,
    required String legacyName,
    required String driftName,
  }) {
    final columns = database
        .select('PRAGMA table_info("${_quote(table)}")')
        .map((row) => row['name'] as String)
        .toSet();

    final hasLegacy = columns.contains(legacyName);
    final hasDrift = columns.contains(driftName);

    if (hasLegacy && hasDrift) {
      throw StateError(
        'Ambiguous Room v6 schema for $table: both $legacyName and '
        '$driftName exist.',
      );
    }
    if (!hasLegacy && hasDrift) {
      return;
    }
    if (!hasLegacy && !hasDrift) {
      throw StateError(
        'Room v6 schema mismatch for $table: neither $legacyName nor '
        '$driftName exists.',
      );
    }

    database.execute(
      'ALTER TABLE "${_quote(table)}" '
      'RENAME COLUMN "${_quote(legacyName)}" '
      'TO "${_quote(driftName)}"',
    );
  }

  String _quote(String value) => value.replaceAll('"', '""');
}
