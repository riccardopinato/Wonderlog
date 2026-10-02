enum CaptureContentType { image, text, link, place, file }

final class CaptureLocation {
  const CaptureLocation({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  final double latitude;
  final double longitude;
  final String? label;
}

final class CaptureIncomingItem {
  const CaptureIncomingItem({
    required this.id,
    required this.type,
    this.uri,
    this.text,
    this.title,
    this.mimeType,
    this.location,
  });

  final String id;
  final CaptureContentType type;
  final String? uri;
  final String? text;
  final String? title;
  final String? mimeType;
  final CaptureLocation? location;
}

final class CaptureDraft {
  const CaptureDraft({
    required this.items,
    this.journeyId,
    this.memoryId,
    this.createNewMemory = false,
    this.memoryTitle = '',
    this.memoryText = '',
    this.location,
  });

  final List<CaptureIncomingItem> items;
  final String? journeyId;
  final String? memoryId;
  final bool createNewMemory;
  final String memoryTitle;
  final String memoryText;
  final CaptureLocation? location;

  bool get hasImages =>
      items.any((item) => item.type == CaptureContentType.image);

  bool get hasFiles =>
      items.any((item) => item.type == CaptureContentType.file);

  bool get hasText => items.any(
        (item) =>
            item.type == CaptureContentType.text ||
            item.type == CaptureContentType.link,
      );
}
