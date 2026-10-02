final class SmartJourneySourcePhoto {
  const SmartJourneySourcePhoto({
    required this.sourceUri,
    required this.originalIndex,
    this.capturedAt,
    this.modifiedAt,
    this.latitude,
    this.longitude,
    this.placeLabel,
    this.included = true,
  });

  final String sourceUri;
  final int originalIndex;
  final DateTime? capturedAt;
  final DateTime? modifiedAt;
  final double? latitude;
  final double? longitude;
  final String? placeLabel;
  final bool included;

  DateTime? get effectiveTimestamp => capturedAt ?? modifiedAt;
}

final class SmartJourneyPhoto {
  const SmartJourneyPhoto({
    required this.id,
    required this.source,
    required this.dayIndex,
    required this.stopId,
    this.included = true,
  });

  final String id;
  final SmartJourneySourcePhoto source;
  final int dayIndex;
  final String? stopId;
  final bool included;

  SmartJourneyPhoto copyWith({
    int? dayIndex,
    String? stopId,
    bool? included,
  }) =>
      SmartJourneyPhoto(
        id: id,
        source: source,
        dayIndex: dayIndex ?? this.dayIndex,
        stopId: stopId ?? this.stopId,
        included: included ?? this.included,
      );
}

final class SmartJourneyStopDraft {
  const SmartJourneyStopDraft({
    required this.id,
    required this.dayIndex,
    required this.title,
    required this.latitude,
    required this.longitude,
    required this.placeLabel,
    required this.photoIds,
    this.createMemory = true,
    this.manuallyEdited = false,
  });

  final String id;
  final int dayIndex;
  final String title;
  final double? latitude;
  final double? longitude;
  final String? placeLabel;
  final List<String> photoIds;
  final bool createMemory;
  final bool manuallyEdited;

  SmartJourneyStopDraft copyWith({
    String? title,
    double? latitude,
    double? longitude,
    List<String>? photoIds,
    bool? createMemory,
    bool? manuallyEdited,
  }) =>
      SmartJourneyStopDraft(
        id: id,
        dayIndex: dayIndex,
        title: title ?? this.title,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        placeLabel: placeLabel,
        photoIds: photoIds ?? this.photoIds,
        createMemory: createMemory ?? this.createMemory,
        manuallyEdited: manuallyEdited ?? this.manuallyEdited,
      );
}

final class SmartJourneyDayDraft {
  const SmartJourneyDayDraft({
    required this.index,
    required this.date,
    required this.title,
    required this.stops,
  });

  final int index;
  final DateTime date;
  final String title;
  final List<SmartJourneyStopDraft> stops;

  SmartJourneyDayDraft copyWith({
    String? title,
    List<SmartJourneyStopDraft>? stops,
  }) =>
      SmartJourneyDayDraft(
        index: index,
        date: date,
        title: title ?? this.title,
        stops: stops ?? this.stops,
      );
}

final class SmartJourneyDraft {
  const SmartJourneyDraft({
    required this.id,
    required this.suggestedTitle,
    required this.title,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.photos,
    this.createMemoryDrafts = true,
    this.analysedPhotoCount = 0,
    this.excludedPhotoCount = 0,
  });

  final String id;
  final String suggestedTitle;
  final String title;
  final String destination;
  final DateTime? startDate;
  final DateTime? endDate;
  final List<SmartJourneyDayDraft> days;
  final List<SmartJourneyPhoto> photos;
  final bool createMemoryDrafts;
  final int analysedPhotoCount;
  final int excludedPhotoCount;

  List<SmartJourneyPhoto> get includedPhotos =>
      photos.where((photo) => photo.included).toList(growable: false);

  int get stopCount =>
      days.fold<int>(0, (sum, day) => sum + day.stops.length);

  SmartJourneyDraft copyWith({
    String? title,
    String? destination,
    List<SmartJourneyDayDraft>? days,
    List<SmartJourneyPhoto>? photos,
    bool? createMemoryDrafts,
    int? excludedPhotoCount,
  }) =>
      SmartJourneyDraft(
        id: id,
        suggestedTitle: suggestedTitle,
        title: title ?? this.title,
        destination: destination ?? this.destination,
        startDate: startDate,
        endDate: endDate,
        days: days ?? this.days,
        photos: photos ?? this.photos,
        createMemoryDrafts: createMemoryDrafts ?? this.createMemoryDrafts,
        analysedPhotoCount: analysedPhotoCount,
        excludedPhotoCount: excludedPhotoCount ?? this.excludedPhotoCount,
      );
}

enum SmartJourneyAnalysisPhase {
  readingMetadata,
  groupingDays,
  clusteringLocations,
  resolvingPlaces,
  buildingDraft,
  complete,
}

final class SmartJourneyAnalysisProgress {
  const SmartJourneyAnalysisProgress({
    required this.processed,
    required this.total,
    required this.phase,
  });

  final int processed;
  final int total;
  final SmartJourneyAnalysisPhase phase;

  double get fraction =>
      total <= 0 ? 0 : (processed / total).clamp(0.0, 1.0);
}

final class SmartJourneyBuildOptions {
  const SmartJourneyBuildOptions({
    this.geoClusterRadiusMeters = 2500,
    this.maxStopTimeGapMinutes = 240,
    this.orphanAssignmentTimeWindowMinutes = 360,
    this.minimumPhotosPerStop = 1,
    this.createMemoryDrafts = true,
  });

  final double geoClusterRadiusMeters;
  final int maxStopTimeGapMinutes;
  final int orphanAssignmentTimeWindowMinutes;
  final int minimumPhotosPerStop;
  final bool createMemoryDrafts;
}

final class SmartJourneyCreationAllowance {
  const SmartJourneyCreationAllowance({
    required this.isPremium,
    required this.journeyCreationAllowed,
    required this.selectedPhotoCount,
    required this.allowedPhotoCount,
    required this.blockedPhotoCount,
  });

  final bool isPremium;
  final bool journeyCreationAllowed;
  final int selectedPhotoCount;
  final int allowedPhotoCount;
  final int blockedPhotoCount;

  bool get journeyLimitReached => !journeyCreationAllowed;
  bool get hasBlockedPhotos => blockedPhotoCount > 0;
  bool get requiresUpgrade =>
      !isPremium && (journeyLimitReached || hasBlockedPhotos);
  bool get allPhotosAllowed => blockedPhotoCount == 0;
}
