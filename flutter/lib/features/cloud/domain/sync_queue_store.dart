import 'cloud_models.dart';

abstract interface class SyncQueueStore {
  Stream<int> watchPendingCount();

  Future<void> enqueue(SyncQueueItem item);

  Future<List<SyncQueueItem>> nextBatch({
    required int limit,
    bool includePhotoUploads = true,
  });

  Future<void> remove(String id);

  Future<void> markFailure({
    required String id,
    required String error,
  });

  Future<void> clear();
}
