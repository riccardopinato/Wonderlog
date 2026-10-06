import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/cloud_codec.dart';
import '../domain/cloud_models.dart';
import '../domain/cloud_provider.dart';

final class SupabaseCloudProvider implements CloudProvider {
  SupabaseCloudProvider({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  static const photosBucket = 'wonderlog-photos';
  static const journeysTable = 'journeys';
  static const memoriesTable = 'memories';
  static const photosTable = 'album_photos';
  static const memoryPhotosTable = 'memory_photos';

  final SupabaseClient client;

  @override
  Future<bool> isAuthenticated() async =>
      client.auth.currentSession?.user.id != null;

  @override
  Future<CloudJourney> uploadJourney(CloudJourney payload) async {
    final userId = _requireUserId();
    final rows = await client
        .from(journeysTable)
        .upsert(CloudCodec.journeyToJson(payload, ownerId: userId))
        .select();
    return CloudCodec.journeyFromJson(
      Map<String, dynamic>.from((rows as List).single as Map),
    );
  }

  @override
  Future<CloudMemory> uploadMemory(CloudMemory payload) async {
    final userId = _requireUserId();
    final rows = await client
        .from(memoriesTable)
        .upsert(CloudCodec.memoryToJson(payload, ownerId: userId))
        .select();
    return CloudCodec.memoryFromJson(
      Map<String, dynamic>.from((rows as List).single as Map),
    );
  }

  @override
  Future<CloudAlbumPhoto> uploadPhotoMetadata(
    CloudAlbumPhoto payload,
  ) async {
    final userId = _requireUserId();
    final rows = await client
        .from(photosTable)
        .upsert(CloudCodec.photoToJson(payload, ownerId: userId))
        .select();
    return CloudCodec.photoFromJson(
      Map<String, dynamic>.from((rows as List).single as Map),
    );
  }

  @override
  Future<String> uploadPhotoFile(
    Uint8List bytes,
    String remotePath,
  ) async {
    _requireUserId();
    if (bytes.isEmpty) {
      throw ArgumentError('Photo bytes cannot be empty.');
    }

    await client.storage.from(photosBucket).uploadBinary(
          remotePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
    return remotePath;
  }

  @override
  Future<void> deleteJourney(String cloudId) async {
    final userId = _requireUserId();
    await client
        .from(journeysTable)
        .delete()
        .eq('id', cloudId)
        .eq('owner_id', userId);
  }

  @override
  Future<void> deleteMemory(String cloudId) async {
    final userId = _requireUserId();
    await client
        .from(memoriesTable)
        .delete()
        .eq('id', cloudId)
        .eq('owner_id', userId);
  }

  @override
  Future<void> deletePhoto(
    String cloudId,
    String? remoteFilePath,
  ) async {
    final userId = _requireUserId();
    final path = remoteFilePath?.trim();
    if (path != null && path.isNotEmpty) {
      await client.storage.from(photosBucket).remove([path]);
    }

    await client
        .from(photosTable)
        .delete()
        .eq('id', cloudId)
        .eq('owner_id', userId);
  }

  @override
  Future<List<CloudJourney>> fetchJourneys(
    DateTime? updatedAfter,
  ) async {
    final userId = _requireUserId();
    final List<dynamic> rows = updatedAfter == null
        ? await client.from(journeysTable).select().eq('owner_id', userId)
        : await client
            .from(journeysTable)
            .select()
            .eq('owner_id', userId)
            .gt('updated_at', updatedAfter.toUtc().millisecondsSinceEpoch);
    return rows
        .map(
          (row) => CloudCodec.journeyFromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<CloudMemory>> fetchMemories(
    DateTime? updatedAfter,
  ) async {
    final userId = _requireUserId();
    final List<dynamic> rows = updatedAfter == null
        ? await client.from(memoriesTable).select().eq('owner_id', userId)
        : await client
            .from(memoriesTable)
            .select()
            .eq('owner_id', userId)
            .gt('updated_at', updatedAfter.toUtc().millisecondsSinceEpoch);
    return rows
        .map(
          (row) => CloudCodec.memoryFromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<CloudAlbumPhoto>> fetchPhotos(
    DateTime? updatedAfter,
  ) async {
    final userId = _requireUserId();
    final List<dynamic> rows = updatedAfter == null
        ? await client.from(photosTable).select().eq('owner_id', userId)
        : await client
            .from(photosTable)
            .select()
            .eq('owner_id', userId)
            .gt('updated_at', updatedAfter.toUtc().millisecondsSinceEpoch);
    return rows
        .map(
          (row) => CloudCodec.photoFromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<Uint8List> downloadPhotoFile(String remotePath) async {
    _requireUserId();
    return client.storage.from(photosBucket).download(remotePath);
  }

  @override
  Future<void> uploadMemoryPhotoLinks(
    List<CloudMemoryPhotoLink> links,
  ) async {
    final userId = _requireUserId();
    final existing = await fetchMemoryPhotoLinks();

    // Upsert the desired snapshot first. If this fails, the previous cloud
    // relationships are still intact.
    if (links.isNotEmpty) {
      await client.from(memoryPhotosTable).upsert(
            links
                .map(
                  (link) => CloudCodec.linkToJson(
                    link,
                    ownerId: userId,
                  ),
                )
                .toList(growable: false),
          );
    }

    final desiredKeys = links
        .map((link) => link.memoryCloudId + '|' + link.photoCloudId)
        .toSet();

    // Remove only links that no longer exist locally. Partial cleanup is safe:
    // a later manual sync retries the remaining stale links.
    for (final link in existing) {
      final key = link.memoryCloudId + '|' + link.photoCloudId;
      if (desiredKeys.contains(key)) continue;
      await client
          .from(memoryPhotosTable)
          .delete()
          .eq('owner_id', userId)
          .eq('memory_cloud_id', link.memoryCloudId)
          .eq('photo_cloud_id', link.photoCloudId);
    }
  }

  @override
  Future<List<CloudMemoryPhotoLink>> fetchMemoryPhotoLinks() async {
    final userId = _requireUserId();
    final List<dynamic> rows = await client
        .from(memoryPhotosTable)
        .select()
        .eq('owner_id', userId);
    return rows
        .map(
          (row) => CloudCodec.linkFromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  String _requireUserId() {
    final id = client.auth.currentSession?.user.id;
    if (id == null || id.trim().isEmpty) {
      throw StateError('Supabase user is not authenticated.');
    }
    return id;
  }
}
