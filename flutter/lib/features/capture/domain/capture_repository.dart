import 'capture_models.dart';

final class CaptureJourneyOption {
  const CaptureJourneyOption({
    required this.id,
    required this.title,
    this.subtitle,
  });

  final String id;
  final String title;
  final String? subtitle;
}

final class CaptureMemoryOption {
  const CaptureMemoryOption({
    required this.id,
    required this.title,
    this.dateLabel,
  });

  final String id;
  final String title;
  final String? dateLabel;
}

final class CaptureSaveResult {
  const CaptureSaveResult({
    required this.journeyId,
    required this.memoryId,
    required this.importedPhotoCount,
    required this.attachmentCount,
  });

  final String? journeyId;
  final String? memoryId;
  final int importedPhotoCount;
  final int attachmentCount;
}

abstract interface class CaptureRepository {
  Future<List<CaptureJourneyOption>> getJourneys();
  Future<List<CaptureMemoryOption>> getMemories(String journeyId);
  Future<CaptureSaveResult> save(CaptureDraft draft);
}
