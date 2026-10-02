import 'dart:typed_data';

final class JourneyExportData {
  const JourneyExportData({
    required this.journeyId,
    required this.title,
    required this.destination,
    required this.country,
    required this.startDate,
    required this.endDate,
    required this.description,
    required this.coverPhotoUri,
    required this.photos,
    required this.memories,
  });

  final String journeyId;
  final String title;
  final String destination;
  final String country;
  final String startDate;
  final String endDate;
  final String description;
  final String? coverPhotoUri;
  final List<ExportPhoto> photos;
  final List<ExportMemory> memories;
}

final class ExportPhoto {
  const ExportPhoto({
    required this.uri,
    this.caption,
    this.date,
    this.location,
  });

  final String uri;
  final String? caption;
  final String? date;
  final String? location;
}

final class ExportMemory {
  const ExportMemory({
    required this.title,
    required this.journalText,
    required this.date,
    required this.location,
    required this.mood,
    required this.photoUris,
  });

  final String title;
  final String journalText;
  final String date;
  final String? location;
  final String? mood;
  final List<String> photoUris;
}

enum PdfTravelBookStyle {
  classic,
  editorial,
  scrapbook,
}

final class PdfExportOptions {
  const PdfExportOptions({
    this.style = PdfTravelBookStyle.editorial,
    this.includeCover = true,
    this.includeJourneyDescription = true,
    this.includeAlbumPhotos = true,
    this.includeMemories = true,
    this.includeLocations = true,
    this.includeDates = true,
    this.includePageNumbers = true,
  });

  final PdfTravelBookStyle style;
  final bool includeCover;
  final bool includeJourneyDescription;
  final bool includeAlbumPhotos;
  final bool includeMemories;
  final bool includeLocations;
  final bool includeDates;
  final bool includePageNumbers;
}

final class PdfExportResult {
  const PdfExportResult({
    required this.bytes,
    required this.fileName,
    required this.pageCount,
  });

  final Uint8List bytes;
  final String fileName;
  final int pageCount;
}

typedef PdfImageResolver = Future<Uint8List?> Function(String uri);
