import 'dart:typed_data';

import '../../memories/data/photo_import_service.dart';
import '../../memories/domain/memory_models.dart';
import '../../memories/domain/wonderlog_repository.dart';
import '../domain/pdf_export_models.dart';
import 'pdf_travel_book_builder.dart';

final class JourneyPdfExportService {
  JourneyPdfExportService({
    required this.repository,
    required this.photoImportService,
    this.builder = const PdfTravelBookBuilder(),
  });

  final WonderlogRepository repository;
  final PhotoImportService photoImportService;
  final PdfTravelBookBuilder builder;

  Future<PdfExportResult> exportJourney({
    required String journeyId,
    required PdfExportOptions options,
  }) async {
    final journey = await repository.watchJourney(journeyId).first;
    if (journey == null) {
      throw StateError('Journey not found.');
    }

    final photos = await repository.watchAlbum(journeyId).first;
    final memories = await repository.watchMemoriesWithPhotos(journeyId).first;

    AlbumPhotoEntry? cover;
    for (final photo in photos) {
      if (photo.isCoverPhoto) {
        cover = photo;
        break;
      }
    }
    cover ??= photos.isEmpty ? null : photos.first;

    final data = JourneyExportData(
      journeyId: journey.id,
      title: journey.title,
      destination: journey.destination,
      country: journey.country,
      startDate: _dateOnly(journey.startDate),
      endDate: _dateOnly(journey.endDate),
      description: journey.description,
      coverPhotoUri: cover?.localUri,
      photos: photos
          .map(
            (photo) => ExportPhoto(
              uri: photo.localUri,
              caption: photo.fileName,
              date: _dateOnly(photo.capturedAt ?? photo.createdAt),
              location: photo.locationName,
            ),
          )
          .toList(growable: false),
      memories: memories
          .map(
            (entry) => ExportMemory(
              title: entry.memory.title,
              journalText: entry.memory.journalText,
              date: _dateOnly(entry.memory.date),
              location: entry.memory.locationName,
              mood: entry.memory.mood.emoji + ' ' + entry.memory.mood.label,
              photoUris: entry.photos
                  .map((photo) => photo.localUri)
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );

    return builder.build(
      data: data,
      options: options,
      resolveImage: (reference) async {
        final bytes = await photoImportService.readReference(reference);
        return bytes == null ? null : Uint8List.fromList(bytes);
      },
    );
  }

  String _dateOnly(DateTime value) {
    final local = value.toLocal();
    return local.year.toString().padLeft(4, '0') +
        '-' +
        local.month.toString().padLeft(2, '0') +
        '-' +
        local.day.toString().padLeft(2, '0');
  }
}
