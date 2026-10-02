final class RestoreSummary {
  const RestoreSummary({
    this.journeysInserted = 0,
    this.journeysUpdated = 0,
    this.memoriesInserted = 0,
    this.memoriesUpdated = 0,
    this.photosInserted = 0,
    this.photosUpdated = 0,
    this.photoFilesDownloaded = 0,
    this.memoryPhotoLinksRestored = 0,
    this.conflicts = 0,
    this.skipped = 0,
    this.failures = 0,
  });

  final int journeysInserted;
  final int journeysUpdated;
  final int memoriesInserted;
  final int memoriesUpdated;
  final int photosInserted;
  final int photosUpdated;
  final int photoFilesDownloaded;
  final int memoryPhotoLinksRestored;
  final int conflicts;
  final int skipped;
  final int failures;
}

enum RestorePhase {
  preparing,
  journeys,
  memories,
  photos,
  relationships,
  complete,
}

final class RestoreProgress {
  const RestoreProgress({
    required this.phase,
    this.current = 0,
    this.total = 0,
    required this.message,
  });

  final RestorePhase phase;
  final int current;
  final int total;
  final String message;

  double get fraction =>
      total <= 0 ? 0 : (current / total).clamp(0.0, 1.0);
}

sealed class RestoreState {
  const RestoreState();
}

final class RestoreIdle extends RestoreState {
  const RestoreIdle();
}

final class RestoreRunning extends RestoreState {
  const RestoreRunning(this.progress);
  final RestoreProgress progress;
}

final class RestoreSuccess extends RestoreState {
  const RestoreSuccess(this.summary);
  final RestoreSummary summary;
}

final class RestoreError extends RestoreState {
  const RestoreError(this.message);
  final String message;
}
