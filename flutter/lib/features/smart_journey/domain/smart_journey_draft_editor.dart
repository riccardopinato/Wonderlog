import 'geo_math.dart';
import 'smart_journey_models.dart';

abstract final class SmartJourneyDraftEditor {
  static SmartJourneyDraft renameJourney(
    SmartJourneyDraft draft,
    String title,
  ) =>
      draft.copyWith(title: _take(title, 120));

  static SmartJourneyDraft changeDestination(
    SmartJourneyDraft draft,
    String destination,
  ) =>
      draft.copyWith(destination: _take(destination, 120));

  static SmartJourneyDraft renameStop(
    SmartJourneyDraft draft,
    String stopId,
    String title,
  ) {
    return draft.copyWith(
      days: draft.days
          .map(
            (day) => day.copyWith(
              stops: day.stops
                  .map(
                    (stop) => stop.id == stopId
                        ? stop.copyWith(
                            title: _take(title, 120),
                            manuallyEdited: true,
                          )
                        : stop,
                  )
                  .toList(growable: false),
            ),
          )
          .toList(growable: false),
    );
  }

  static SmartJourneyDraft setPhotoIncluded(
    SmartJourneyDraft draft,
    String photoId,
    bool included,
  ) {
    final photos = draft.photos
        .map(
          (photo) => photo.id == photoId
              ? photo.copyWith(included: included)
              : photo,
        )
        .toList(growable: false);
    return draft.copyWith(
      photos: photos,
      excludedPhotoCount: photos.where((photo) => !photo.included).length,
    );
  }

  static SmartJourneyDraft setMemoryDraftEnabled(
    SmartJourneyDraft draft,
    String stopId,
    bool enabled,
  ) =>
      draft.copyWith(
        days: draft.days
            .map(
              (day) => day.copyWith(
                stops: day.stops
                    .map(
                      (stop) => stop.id == stopId
                          ? stop.copyWith(createMemory: enabled)
                          : stop,
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
      );

  static SmartJourneyDraft setAllMemoryDrafts(
    SmartJourneyDraft draft,
    bool enabled,
  ) =>
      draft.copyWith(
        createMemoryDrafts: enabled,
        days: draft.days
            .map(
              (day) => day.copyWith(
                stops: day.stops
                    .map((stop) => stop.copyWith(createMemory: enabled))
                    .toList(growable: false),
              ),
            )
            .toList(growable: false),
      );

  static SmartJourneyDraft mergeAdjacentStops(
    SmartJourneyDraft draft,
    int dayIndex,
    String firstStopId,
    String secondStopId,
  ) {
    SmartJourneyDayDraft? target;
    for (final day in draft.days) {
      if (day.index == dayIndex) {
        target = day;
        break;
      }
    }
    if (target == null) return draft;

    final firstIndex = target.stops.indexWhere((stop) => stop.id == firstStopId);
    final secondIndex =
        target.stops.indexWhere((stop) => stop.id == secondStopId);
    if (firstIndex < 0 ||
        secondIndex < 0 ||
        (firstIndex - secondIndex).abs() != 1) {
      return draft;
    }

    final lower = firstIndex < secondIndex ? firstIndex : secondIndex;
    final upper = firstIndex > secondIndex ? firstIndex : secondIndex;
    final first = target.stops[lower];
    final second = target.stops[upper];

    final coordinates = <({double latitude, double longitude})>[];
    if (GeoMath.isValidCoordinate(first.latitude, first.longitude)) {
      coordinates.add((
        latitude: first.latitude!,
        longitude: first.longitude!,
      ));
    }
    if (GeoMath.isValidCoordinate(second.latitude, second.longitude)) {
      coordinates.add((
        latitude: second.latitude!,
        longitude: second.longitude!,
      ));
    }
    final center = GeoMath.centroid(coordinates);
    final merged = first.copyWith(
      title: first.manuallyEdited
          ? first.title
          : first.placeLabel ?? second.placeLabel ?? first.title,
      latitude: center?.latitude,
      longitude: center?.longitude,
      photoIds: [...first.photoIds, ...second.photoIds],
      createMemory: first.createMemory || second.createMemory,
    );

    final stops = [...target.stops];
    stops.removeAt(upper);
    stops[lower] = merged;
    final moved = second.photoIds.toSet();

    return draft.copyWith(
      days: draft.days
          .map(
            (day) => day.index == dayIndex ? day.copyWith(stops: stops) : day,
          )
          .toList(growable: false),
      photos: draft.photos
          .map(
            (photo) =>
                moved.contains(photo.id) ? photo.copyWith(stopId: merged.id) : photo,
          )
          .toList(growable: false),
    );
  }

  static SmartJourneyDraft movePhoto(
    SmartJourneyDraft draft,
    String photoId,
    String destinationStopId,
  ) {
    SmartJourneyStopDraft? destination;
    for (final day in draft.days) {
      for (final stop in day.stops) {
        if (stop.id == destinationStopId) destination = stop;
      }
    }
    if (destination == null) return draft;

    SmartJourneyPhoto? sourcePhoto;
    for (final photo in draft.photos) {
      if (photo.id == photoId) sourcePhoto = photo;
    }
    if (sourcePhoto == null) return draft;
    final oldStopId = sourcePhoto.stopId;

    final days = draft.days
        .map(
          (day) => day.copyWith(
            stops: day.stops
                .map((stop) {
                  if (stop.id == oldStopId) {
                    return stop.copyWith(
                      photoIds: stop.photoIds
                          .where((id) => id != photoId)
                          .toList(growable: false),
                    );
                  }
                  if (stop.id == destinationStopId) {
                    return stop.copyWith(
                      photoIds: <String>{...stop.photoIds, photoId}.toList(),
                    );
                  }
                  return stop;
                })
                .where((stop) => stop.photoIds.isNotEmpty)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);

    return draft.copyWith(
      days: days,
      photos: draft.photos
          .map(
            (photo) => photo.id == photoId
                ? photo.copyWith(
                    dayIndex: destination!.dayIndex,
                    stopId: destinationStopId,
                  )
                : photo,
          )
          .toList(growable: false),
    );
  }

  static String _take(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}
