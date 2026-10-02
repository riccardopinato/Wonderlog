import 'capture_models.dart';

final class CaptureValidationResult {
  const CaptureValidationResult(this.valid, [this.message]);
  final bool valid;
  final String? message;
}

abstract final class CaptureValidator {
  static CaptureValidationResult validate(CaptureDraft draft) {
    if (draft.journeyId == null) {
      return const CaptureValidationResult(false, 'Choose a Journey.');
    }

    final needsMemory = draft.items.any(
      (item) =>
          item.type == CaptureContentType.text ||
          item.type == CaptureContentType.link ||
          item.type == CaptureContentType.file,
    );

    final hasMemoryDestination =
        draft.memoryId != null || draft.createNewMemory;

    if (needsMemory && !hasMemoryDestination) {
      return const CaptureValidationResult(
        false,
        'Choose a Memory or create a new one.',
      );
    }

    if (draft.createNewMemory &&
        draft.memoryTitle.trim().isEmpty &&
        draft.memoryText.trim().isEmpty &&
        draft.items.isEmpty) {
      return const CaptureValidationResult(
        false,
        'Add something to this Memory.',
      );
    }

    return const CaptureValidationResult(true);
  }
}
