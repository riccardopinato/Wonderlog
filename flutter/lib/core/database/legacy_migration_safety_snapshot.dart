import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

final class LegacyMigrationSnapshot {
  const LegacyMigrationSnapshot({
    required this.directory,
    required this.manifest,
  });

  final Directory directory;
  final Map<String, Object?> manifest;
}

final class LegacyMigrationSafetySnapshot {
  const LegacyMigrationSafetySnapshot();

  Future<LegacyMigrationSnapshot> ensure({
    required File databaseFile,
    required Directory backupRoot,
  }) async {
    if (!await databaseFile.exists()) {
      throw StateError('Legacy database does not exist.');
    }

    final sources = <File>[
      databaseFile,
      File(databaseFile.path + '-wal'),
      File(databaseFile.path + '-shm'),
    ];

    final existingSources = <File>[];
    for (final file in sources) {
      if (await file.exists()) existingSources.add(file);
    }

    final sourceEntries = <Map<String, Object?>>[];
    for (final file in existingSources) {
      sourceEntries.add(await _describe(file));
    }

    final fingerprintPayload = jsonEncode(
      sourceEntries
          .map(
            (entry) => {
              'name': entry['name'],
              'sizeBytes': entry['sizeBytes'],
              'sha256': entry['sha256'],
            },
          )
          .toList(growable: false),
    );
    final fingerprint =
        sha256.convert(utf8.encode(fingerprintPayload)).toString();
    final finalDirectory = Directory(
      '${backupRoot.path}${Platform.pathSeparator}'
      'room_pre_drift_${fingerprint.substring(0, 16)}',
    );

    if (await finalDirectory.exists()) {
      final manifest = await _verifySnapshot(
        finalDirectory,
        expectedSourceEntries: sourceEntries,
        expectedFingerprint: fingerprint,
      );
      return LegacyMigrationSnapshot(
        directory: finalDirectory,
        manifest: manifest,
      );
    }

    await backupRoot.create(recursive: true);
    final staging = Directory(
      '${backupRoot.path}${Platform.pathSeparator}'
      '.staging_${DateTime.now().toUtc().microsecondsSinceEpoch}_$pid',
    );
    await staging.create(recursive: true);

    try {
      for (final source in existingSources) {
        final target = File(
          '${staging.path}${Platform.pathSeparator}'
          '${_basename(source.path)}',
        );
        await source.copy(target.path);
      }

      final afterCopyEntries = <Map<String, Object?>>[];
      for (final source in existingSources) {
        if (!await source.exists()) {
          throw StateError(
            'Legacy database sidecar changed during safety snapshot.',
          );
        }
        afterCopyEntries.add(await _describe(source));
      }
      if (!_sameEntries(sourceEntries, afterCopyEntries)) {
        throw StateError(
          'Legacy database changed during safety snapshot. '
          'Migration was not started.',
        );
      }

      final manifest = <String, Object?>{
        'format': 'wonderlog-room-migration-snapshot',
        'snapshotVersion': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'sourceFingerprint': fingerprint,
        'targetSchemaVersion': 9,
        'files': sourceEntries,
      };
      final manifestFile = File(
        '${staging.path}${Platform.pathSeparator}manifest.json',
      );
      await manifestFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(manifest) + '\n',
        flush: true,
      );

      await _verifySnapshot(
        staging,
        expectedSourceEntries: sourceEntries,
        expectedFingerprint: fingerprint,
      );

      try {
        await staging.rename(finalDirectory.path);
      } on FileSystemException {
        if (!await finalDirectory.exists()) rethrow;
        await staging.delete(recursive: true);
      }

      final verified = await _verifySnapshot(
        finalDirectory,
        expectedSourceEntries: sourceEntries,
        expectedFingerprint: fingerprint,
      );
      return LegacyMigrationSnapshot(
        directory: finalDirectory,
        manifest: verified,
      );
    } catch (_) {
      if (await staging.exists()) {
        await staging.delete(recursive: true);
      }
      rethrow;
    }
  }

  Future<Map<String, Object?>> _verifySnapshot(
    Directory directory, {
    required List<Map<String, Object?>> expectedSourceEntries,
    required String expectedFingerprint,
  }) async {
    final manifestFile = File(
      '${directory.path}${Platform.pathSeparator}manifest.json',
    );
    if (!await manifestFile.exists()) {
      throw StateError('Migration safety snapshot manifest is missing.');
    }

    final decoded = jsonDecode(await manifestFile.readAsString());
    if (decoded is! Map) {
      throw StateError('Migration safety snapshot manifest is invalid.');
    }
    final manifest = Map<String, Object?>.from(decoded);
    if (manifest['format'] != 'wonderlog-room-migration-snapshot' ||
        manifest['snapshotVersion'] != 1 ||
        manifest['sourceFingerprint'] != expectedFingerprint ||
        manifest['targetSchemaVersion'] != 9) {
      throw StateError('Migration safety snapshot manifest does not match.');
    }

    final filesRaw = manifest['files'];
    if (filesRaw is! List) {
      throw StateError('Migration safety snapshot file list is invalid.');
    }
    final listed = filesRaw
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);

    if (!_sameEntries(expectedSourceEntries, listed)) {
      throw StateError('Migration safety snapshot source metadata mismatch.');
    }

    for (final expected in expectedSourceEntries) {
      final name = expected['name']! as String;
      final copy = File(
        '${directory.path}${Platform.pathSeparator}$name',
      );
      if (!await copy.exists()) {
        throw StateError('Migration safety snapshot is missing $name.');
      }
      final described = await _describe(copy);
      if (described['sizeBytes'] != expected['sizeBytes'] ||
          described['sha256'] != expected['sha256']) {
        throw StateError(
          'Migration safety snapshot hash mismatch for $name.',
        );
      }
    }

    return manifest;
  }

  Future<Map<String, Object?>> _describe(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return {
      'name': _basename(file.path),
      'sizeBytes': await file.length(),
      'sha256': digest.toString(),
    };
  }

  bool _sameEntries(
    List<Map<String, Object?>> first,
    List<Map<String, Object?>> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      final a = first[index];
      final b = second[index];
      if (a['name'] != b['name'] ||
          a['sizeBytes'] != b['sizeBytes'] ||
          a['sha256'] != b['sha256']) {
        return false;
      }
    }
    return true;
  }

  String _basename(String path) =>
      path.split(Platform.pathSeparator).last;
}
