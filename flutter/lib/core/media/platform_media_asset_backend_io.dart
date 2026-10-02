import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'media_asset_backend.dart';
import 'media_asset_models.dart';

Future<MediaAssetBackend> createPlatformMediaAssetBackend() async {
  final root = await getApplicationSupportDirectory();
  final directory = Directory(p.join(root.path, 'wonderlog_media'));
  await directory.create(recursive: true);
  return FileMediaAssetBackend(directory);
}

final class FileMediaAssetBackend implements MediaAssetBackend {
  FileMediaAssetBackend(this.root);

  final Directory root;

  @override
  Future<void> write(String assetId, List<int> bytes) async {
    final file = _file(assetId);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
  }

  @override
  Future<List<int>?> read(String assetId) async {
    final file = _file(assetId);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  @override
  Future<bool> delete(String assetId) async {
    final file = _file(assetId);
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }

  @override
  Future<Set<String>> listAssetIds() async {
    if (!await root.exists()) return <String>{};
    final ids = <String>{};
    await for (final entity in root.list(recursive: false)) {
      if (entity is File) ids.add(p.basename(entity.path));
    }
    return ids;
  }

  @override
  Future<Map<String, MediaAssetStats>> stats() async {
    final result = <String, MediaAssetStats>{};
    if (!await root.exists()) return result;

    await for (final entity in root.list(recursive: false)) {
      if (entity is! File) continue;
      final stat = await entity.stat();
      result[p.basename(entity.path)] = MediaAssetStats(
        sizeBytes: stat.size,
        lastAccessedAt: stat.accessed.toUtc(),
      );
    }
    return result;
  }

  File _file(String assetId) {
    if (!RegExp(r'^[a-zA-Z0-9_.-]{1,160}$').hasMatch(assetId)) {
      throw ArgumentError.value(assetId, 'assetId', 'Unsafe asset id.');
    }
    return File(p.join(root.path, assetId));
  }
}
