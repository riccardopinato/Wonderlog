import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'geo_photo_clusterer.dart';
import 'smart_journey_models.dart';
import 'temporal_photo_grouper.dart';

typedef PlaceResolver = Future<String?> Function(
  double latitude,
  double longitude,
);

final class SmartJourneyReconstructionEngine {
  SmartJourneyReconstructionEngine({
    this.options = const SmartJourneyBuildOptions(),
    Uuid? uuid,
  }) : _uuid = uuid ?? const Uuid();

  final SmartJourneyBuildOptions options;
  final Uuid _uuid;

  Future<SmartJourneyDraft> reconstruct(
    List<SmartJourneySourcePhoto> photos, {
    required PlaceResolver resolvePlace,
  }) async {
    if (photos.isEmpty) {
      throw ArgumentError('At least one photo is required.');
    }

    final dayGroups = const TemporalPhotoGrouper().group(photos);
    final clusterer = GeoPhotoClusterer(options);
    final allPhotos = <SmartJourneyPhoto>[];
    final days = <SmartJourneyDayDraft>[];

    for (var dayIndex = 0; dayIndex < dayGroups.length; dayIndex++) {
      final day = dayGroups[dayIndex];
      final clusters = clusterer.cluster(day.photos);
      final stops = <SmartJourneyStopDraft>[];

      for (var stopIndex = 0; stopIndex < clusters.length; stopIndex++) {
        final cluster = clusters[stopIndex];
        final stopId = _uuid.v4();

        String? resolvedPlace;
        if (cluster.latitude != null && cluster.longitude != null) {
          try {
            resolvedPlace = await resolvePlace(
              cluster.latitude!,
              cluster.longitude!,
            );
          } catch (_) {
            resolvedPlace = null;
          }
        }

        final counts = <String, int>{};
        for (final photo in cluster.photos) {
          final value = photo.placeLabel?.trim();
          if (value != null && value.isNotEmpty) {
            counts[value] = (counts[value] ?? 0) + 1;
          }
        }
        String? metadataPlace;
        for (final entry in counts.entries) {
          if (metadataPlace == null ||
              entry.value > (counts[metadataPlace] ?? 0)) {
            metadataPlace = entry.key;
          }
        }

        final placeLabel = resolvedPlace ?? metadataPlace;
        final title = placeLabel ?? 'Stop ' + (stopIndex + 1).toString();
        final photoIds = <String>[];

        for (final source in cluster.photos) {
          final id = _uuid.v4();
          photoIds.add(id);
          allPhotos.add(
            SmartJourneyPhoto(
              id: id,
              source: source,
              dayIndex: dayIndex,
              stopId: stopId,
            ),
          );
        }

        stops.add(
          SmartJourneyStopDraft(
            id: stopId,
            dayIndex: dayIndex,
            title: title,
            latitude: cluster.latitude,
            longitude: cluster.longitude,
            placeLabel: placeLabel,
            photoIds: photoIds,
            createMemory: options.createMemoryDrafts,
          ),
        );
      }

      days.add(
        SmartJourneyDayDraft(
          index: dayIndex,
          date: day.date,
          title: 'Day ' + (dayIndex + 1).toString(),
          stops: stops,
        ),
      );
    }

    final placeCounts = <String, int>{};
    for (final day in days) {
      for (final stop in day.stops) {
        final label = stop.placeLabel;
        if (label != null) {
          placeCounts[label] = (placeCounts[label] ?? 0) + 1;
        }
      }
    }

    String destination = '';
    for (final entry in placeCounts.entries) {
      if (destination.isEmpty ||
          entry.value > (placeCounts[destination] ?? 0)) {
        destination = entry.key;
      }
    }

    final startDate = days.isEmpty ? null : days.first.date;
    final endDate = days.isEmpty ? null : days.last.date;
    final formatter = DateFormat('MMM yyyy');
    final suggestedTitle = destination.isNotEmpty && startDate != null
        ? destination + ' ' + formatter.format(startDate)
        : destination.isNotEmpty
            ? destination
            : startDate != null
                ? 'Journey ' + formatter.format(startDate)
                : 'New Journey';

    return SmartJourneyDraft(
      id: _uuid.v4(),
      suggestedTitle: suggestedTitle,
      title: suggestedTitle,
      destination: destination,
      startDate: startDate,
      endDate: endDate,
      days: days,
      photos: allPhotos,
      createMemoryDrafts: options.createMemoryDrafts,
      analysedPhotoCount: photos.length,
    );
  }
}
